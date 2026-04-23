// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.openvibble.nusperipheral.BuddyPeripheralService
import com.openvibble.nusperipheral.NusConnectionState
import com.openvibble.persona.PersonaSelectionStore
import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.protocol.PermissionDecision
import com.openvibble.runtime.BatterySample
import com.openvibble.runtime.BridgeRuntime
import com.openvibble.runtime.BridgeSnapshot
import com.openvibble.runtime.ProjectSummary
import com.openvibble.runtime.ProjectSummaryBuilder
import com.openvibble.runtime.PromptRequest
import com.openvibble.runtime.StatsSample
import com.openvibble.runtime.StatusSample
import com.openvibble.settings.AppSettings
import com.openvibble.settings.SharedPreferencesPersonaSelectionStore
import com.openvibble.stats.PersonaStatsStore
import com.openvibble.storage.CharacterTransferStore
import com.openvibble.storage.TransferProgress
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.launch

/**
 * Android parity with iOS `BridgeAppModel` (OpenVibbleApp/BridgeAppModel.swift).
 *
 * Glues [BridgeRuntime] and [BuddyPeripheralService] into a single observable
 * surface for Compose screens. LiveActivity code from the iOS model has no
 * Android analogue and is intentionally omitted.
 *
 * Lifecycle: owned by Compose via `viewModel()`; tied to the process because
 * the BLE foreground service keeps it alive across configuration changes.
 */
class BridgeAppModel(
    private val context: Context,
    private val runtime: BridgeRuntime,
    private val peripheral: BuddyPeripheralService,
    val statsStore: PersonaStatsStore,
    private val settings: AppSettings,
) : ViewModel() {

    // Re-expose runtime/peripheral state flows directly — UI just binds to these.
    val snapshot: StateFlow<BridgeSnapshot> = runtime.snapshot
    val prompt: StateFlow<PromptRequest?> = runtime.prompt
    val transfer: StateFlow<TransferProgress> = runtime.transferProgress
    val connectionState: StateFlow<NusConnectionState> = peripheral.connectionState
    val bluetoothStateNote: StateFlow<String> = peripheral.bluetoothStateNote
    val bluetoothPowerState: StateFlow<com.openvibble.nusperipheral.BluetoothPowerState> = peripheral.powerState
    val advertisingNote: StateFlow<String> = peripheral.advertisingNote
    val diagnosticLogs: StateFlow<List<String>> = peripheral.diagnostics

    private val _activeDisplayName = MutableStateFlow(DEFAULT_DISPLAY_NAME)
    val activeDisplayName: StateFlow<String> = _activeDisplayName.asStateFlow()

    private val _recentEvents = MutableStateFlow<List<String>>(emptyList())
    val recentEvents: StateFlow<List<String>> = _recentEvents.asStateFlow()

    private val _parsedEntries = MutableStateFlow<List<String>>(emptyList())
    val parsedEntries: StateFlow<List<String>> = _parsedEntries.asStateFlow()

    private val _lastInstalledCharacter = MutableStateFlow<String?>(null)
    val lastInstalledCharacter: StateFlow<String?> = _lastInstalledCharacter.asStateFlow()

    private val _recentLevelUp = MutableStateFlow(false)
    val recentLevelUp: StateFlow<Boolean> = _recentLevelUp.asStateFlow()

    private val _lastQuickApprovalAt = MutableStateFlow<Long?>(null)
    val lastQuickApprovalAt: StateFlow<Long?> = _lastQuickApprovalAt.asStateFlow()

    private val _lastCompletedAt = MutableStateFlow<Long?>(null)
    val lastCompletedAt: StateFlow<Long?> = _lastCompletedAt.asStateFlow()

    private val _responseSent = MutableStateFlow(false)
    val responseSent: StateFlow<Boolean> = _responseSent.asStateFlow()

    /**
     * Per-project grouping of heartbeat entries, same API as iOS
     * `BridgeAppModel.projects`. Lazily computed via a cold-then-hot flow so
     * INFO > CLAUDE can collect it without forcing every Home-screen
     * recomposition to rebuild.
     */
    val projects: StateFlow<List<ProjectSummary>> =
        combine(_parsedEntries, runtime.prompt) { entries, p ->
            ProjectSummaryBuilder.build(entries = entries, hasPrompt = p != null)
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.Eagerly,
            initialValue = emptyList(),
        )

    val charactersRoot: File get() = runtime.charactersRoot

    private var started: Boolean = false
    private var lastPromptId: String? = null
    private var lastPromptAtMs: Long? = null

    /** Pluggable hook for BuddyNotificationCenter so the port stays decoupled. */
    interface NotificationsBridge {
        fun notifyPromptIfNeeded(promptId: String, tool: String, enabled: Boolean)
        fun notifyLevelUpIfNeeded(level: Int, enabled: Boolean)
        fun clearPromptNotifications(promptId: String)
    }
    var notifications: NotificationsBridge? = null

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) { pushStatusSample() }
    }

    init {
        runtime.onCharacterInstalled = { name ->
            _lastInstalledCharacter.value = name
            recordEvent("系统 已安装宠物：$name")
        }
        runtime.onSpeciesChanged = { idx ->
            val line = when {
                idx == PersonaSpeciesCatalog.GIF_SENTINEL -> "系统 切换宠物 → GIF"
                else -> PersonaSpeciesCatalog.nameAt(idx)?.let { "系统 切换宠物 → $it (idx=$idx)" }
            }
            if (line != null) recordEvent(line)
        }
        runtime.onTaskCompleted = { _lastCompletedAt.value = System.currentTimeMillis() }

        peripheral.onLineReceived = { line ->
            recordEvent("接收  $line")
            val outbound = runtime.ingestLine(line)
            refreshFromRuntime()
            for (response in outbound) {
                recordEvent("发送  ${response.trim()}")
                peripheral.sendLine(response)
            }
        }

        // Runtime snapshot mutations happen outside refreshFromRuntime (e.g.
        // from status commands). Mirror snapshot.entries into parsedEntries
        // whenever it changes so INFO > CLAUDE always has fresh content.
        viewModelScope.launch {
            runtime.snapshot.collect { snap ->
                mergeParsedEntries(snap.entries)
            }
        }

        enableBatteryMonitoring()
    }

    fun start(includeServiceUuidInAdvertisement: Boolean = true) {
        if (started) return
        val name = DEFAULT_DISPLAY_NAME
        _activeDisplayName.value = name
        peripheral.setAdvertisementMode(includeServiceUuidInAdvertisement)
        peripheral.start(name)
        recordEvent("系统 请求启动广播：$name")
        refreshFromRuntime()
        started = true
    }

    fun stop() {
        if (!started) return
        peripheral.stop()
        recordEvent("系统 BLE 外设已停止")
        started = false
    }

    /** Returns elapsed ms since the prompt appeared, or null if no active prompt. */
    fun respondPermission(decision: PermissionDecision): Long? {
        val answeredId = runtime.prompt.value?.id
        val line = runtime.respondPermission(decision) ?: return null
        val direction = if (decision == PermissionDecision.ONCE) "允许" else "拒绝"
        recordEvent("发送  权限$direction")
        peripheral.sendLine(line)

        val elapsedMs = lastPromptAtMs?.let { System.currentTimeMillis() - it }
        when (decision) {
            PermissionDecision.ONCE -> {
                statsStore.onApproval(secondsToRespond = (elapsedMs ?: 0L).toDouble() / 1000.0)
                if (elapsedMs != null && elapsedMs < QUICK_APPROVAL_THRESHOLD_MS) {
                    _lastQuickApprovalAt.value = System.currentTimeMillis()
                }
            }
            PermissionDecision.DENY -> statsStore.onDenial()
        }
        lastPromptAtMs = null
        lastPromptId = null
        _responseSent.value = true
        answeredId?.let { notifications?.clearPromptNotifications(it) }
        pushStatusSample()
        return elapsedMs
    }

    fun clearLogs() {
        _recentEvents.value = emptyList()
        _parsedEntries.value = emptyList()
    }

    fun logDeviceMenuEvent(description: String) {
        recordEvent("设备 $description")
    }

    private fun mergeParsedEntries(incoming: List<String>) {
        if (incoming.isEmpty()) return
        val merged = _parsedEntries.value.toMutableList()
        for (entry in incoming.asReversed()) {
            val window = merged.take(PARSED_ENTRIES_DEDUP_WINDOW)
            if (window.contains(entry)) continue
            merged.add(0, entry)
        }
        if (merged.size > PARSED_ENTRIES_MAX) {
            merged.subList(PARSED_ENTRIES_MAX, merged.size).clear()
        }
        _parsedEntries.value = merged
    }

    private fun refreshFromRuntime() {
        val snap = runtime.snapshot.value
        mergeParsedEntries(snap.entries)

        val newPrompt = runtime.prompt.value
        if (newPrompt != null && newPrompt.id != lastPromptId) {
            lastPromptId = newPrompt.id
            lastPromptAtMs = System.currentTimeMillis()
            _responseSent.value = false
            notifications?.notifyPromptIfNeeded(
                promptId = newPrompt.id,
                tool = newPrompt.tool,
                enabled = settings.notificationsEnabled,
            )
        } else if (newPrompt == null) {
            lastPromptAtMs = null
            lastPromptId = null
            _responseSent.value = false
        }

        val leveled = statsStore.onBridgeTokens(bridgeTotal = snap.tokens.toLong())
        if (leveled) {
            _recentLevelUp.value = true
            val level = statsStore.stats.value.level
            recordEvent("系统 升级！等级 $level")
            notifications?.notifyLevelUpIfNeeded(level = level.toInt(), enabled = settings.notificationsEnabled)
            viewModelScope.launch {
                kotlinx.coroutines.delay(3_000L)
                _recentLevelUp.value = false
            }
        }
        pushStatusSample()
    }

    private fun enableBatteryMonitoring() {
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        context.registerReceiver(batteryReceiver, filter)
        pushStatusSample()
    }

    private fun pushStatusSample() {
        val battery = readBattery() ?: BatterySample(percent = 100, usb = true)
        val s = statsStore.stats.value
        val sample = StatusSample(
            battery = battery,
            stats = StatsSample(
                approvals = s.approvals.toInt(),
                denials = s.denials.toInt(),
                velocityMedianSeconds = s.medianVelocitySeconds.toInt(),
                napSeconds = s.napSeconds.toInt(),
                level = s.level.toInt(),
            ),
        )
        runtime.updateStatusSample(sample)
    }

    private fun readBattery(): BatterySample? {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return null
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val percent = if (level < 0 || scale <= 0) 100 else ((level.toFloat() / scale.toFloat()) * 100f).toInt()
        val statusInt = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
        val usb = statusInt == BatteryManager.BATTERY_STATUS_CHARGING || statusInt == BatteryManager.BATTERY_STATUS_FULL
        val millivolts = intent.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0)
        return BatterySample(percent = percent, millivolts = millivolts, milliamps = 0, usb = usb)
    }

    private fun recordEvent(line: String) {
        val current = _recentEvents.value.toMutableList()
        current.add(0, line)
        if (current.size > RECENT_EVENTS_MAX) {
            current.subList(RECENT_EVENTS_MAX, current.size).clear()
        }
        _recentEvents.value = current
    }

    override fun onCleared() {
        runCatching { context.unregisterReceiver(batteryReceiver) }
        stop()
        super.onCleared()
    }

    companion object {
        const val DEFAULT_DISPLAY_NAME: String = "claude.openvibble"
        const val RECENT_EVENTS_MAX: Int = 120
        const val PARSED_ENTRIES_MAX: Int = 200
        const val PARSED_ENTRIES_DEDUP_WINDOW: Int = 16
        const val QUICK_APPROVAL_THRESHOLD_MS: Long = 5_000L
    }

    class Factory(private val applicationContext: Context) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            require(modelClass.isAssignableFrom(BridgeAppModel::class.java)) {
                "Unsupported ViewModel: $modelClass"
            }
            val charactersRoot = File(applicationContext.filesDir, "characters").apply { mkdirs() }
            val transferStore = CharacterTransferStore(rootDirectory = charactersRoot)
            val personaSelection = SharedPreferencesPersonaSelectionStore(applicationContext)
            val runtime = BridgeRuntime(
                transferStore = transferStore,
                personaSelection = personaSelection,
            )
            val peripheral = BuddyPeripheralService(applicationContext)
            val statsStore = PersonaStatsStore()
            val settings = AppSettings(applicationContext)
            @Suppress("UNCHECKED_CAST")
            return BridgeAppModel(
                context = applicationContext,
                runtime = runtime,
                peripheral = peripheral,
                statsStore = statsStore,
                settings = settings,
            ) as T
        }
    }
}
