// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.content.Intent
import android.provider.Settings
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.border
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.nav.NavigationCoordinator
import com.openvibble.nusperipheral.BluetoothPowerState
import com.openvibble.nusperipheral.NusConnectionState
import com.openvibble.persona.PersonaController
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.persona.PersonaState
import com.openvibble.settings.SharedPreferencesPersonaSelectionStore
import com.openvibble.protocol.PermissionDecision
import com.openvibble.runtime.PromptRequest
import com.openvibble.settings.AppSettings
import com.openvibble.ui.species.AsciiBuddyView
import com.openvibble.ui.species.SpeciesRegistry
import com.openvibble.ui.terminal.ScanlineOverlay
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Android parity with iOS `HomeScreen` (OpenVibbleApp/Home/HomeScreen.swift).
 *
 * Layout mirrors the handheld-style "the phone screen is the dev-board
 * screen" treatment:
 *
 *   ┌──────────────────────────┐
 *   │ ● BLE:conn          ⚙    │
 *   │        [pet area]        │
 *   ├──────────────────────────┤
 *   │  NORMAL / PET / INFO     │
 *   ├──────────────────────────┤
 *   │  A  B          [≣ Log]   │
 *   └──────────────────────────┘
 *
 * A short-press cycles NORMAL → PET → INFO. B short-presses:
 *   - NORMAL with prompt: deny
 *   - PET / INFO: next internal page
 *   - otherwise: ignored
 * Horizontal swipe also pages PET/INFO (fires once per gesture on release).
 */
@Composable
fun HomeScreen(
    model: BridgeAppModel,
    persona: PersonaController,
    navigation: NavigationCoordinator,
    settings: AppSettings,
    onOpenSettings: () -> Unit,
    onOpenLogs: () -> Unit = {},
    onLongPressA: () -> Unit = {},
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val appStartMs = remember { System.currentTimeMillis() }
    var mode by remember { mutableStateOf(DisplayMode.NORMAL) }
    var petPage by remember { mutableIntStateOf(0) }
    var infoPage by remember { mutableIntStateOf(0) }

    val snapshot by model.snapshot.collectAsState()
    val prompt by model.prompt.collectAsState()
    val responseSent by model.responseSent.collectAsState()
    val parsedEntries by model.parsedEntries.collectAsState()
    val connectionState by model.connectionState.collectAsState()
    val powerState by model.bluetoothPowerState.collectAsState()
    val pendingRoute by navigation.pendingRoute.collectAsState()
    val personaState by persona.state.collectAsState()

    var showPowerButton by remember { mutableStateOf(settings.showPowerButton) }

    // Prompt-waited timer — ticks every 1s while prompt is pending so the
    // "waited Ns" label counts up without the whole screen recomposing from
    // other state sources.
    var promptArrivedAtMs by remember { mutableStateOf<Long?>(null) }
    var frozenWaitedSeconds by remember { mutableStateOf<Int?>(null) }
    var promptTickNow by remember { mutableStateOf(System.currentTimeMillis()) }

    LaunchedEffect(prompt?.id) {
        if (prompt != null) {
            promptArrivedAtMs = System.currentTimeMillis()
            frozenWaitedSeconds = null
        } else {
            promptArrivedAtMs = null
            frozenWaitedSeconds = null
        }
    }
    LaunchedEffect(responseSent, promptArrivedAtMs) {
        if (responseSent && frozenWaitedSeconds == null && promptArrivedAtMs != null) {
            frozenWaitedSeconds = waitedSeconds(promptArrivedAtMs, System.currentTimeMillis())
        }
    }
    LaunchedEffect(promptArrivedAtMs) {
        while (promptArrivedAtMs != null) {
            promptTickNow = System.currentTimeMillis()
            delay(1_000L)
        }
    }

    // Deep-link: openvibble://status forces NORMAL mode.
    LaunchedEffect(pendingRoute) {
        val route = pendingRoute ?: return@LaunchedEffect
        when (route) {
            NavigationCoordinator.Route.Status -> mode = DisplayMode.NORMAL
        }
        navigation.clearPending()
    }

    // Kick the advertiser once on entry if BLE is permitted. A dedicated
    // permission watcher lives in the caller (MainActivity) — here we just
    // call start(); the peripheral service no-ops if permissions are missing.
    LaunchedEffect(Unit) { model.start() }

    val waited: Int = frozenWaitedSeconds
        ?: waitedSeconds(promptArrivedAtMs, promptTickNow)

    val deviceMenu = remember { DeviceMenuState(context) }
    var showAdvertisingHelp by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(TerminalPalette.lcdBg)) {
        ScanlineOverlay()

        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val availableHeightPx = constraints.maxHeight.toFloat()
            val petAreaDp = computePetAreaHeightDp(availableHeightPx)
            Column(modifier = Modifier.fillMaxSize()) {
                TopBar(
                    connectionState = connectionState,
                    powerState = powerState,
                    onOpenSettings = onOpenSettings,
                    onStartAdvertising = { model.start() },
                    onRestartAdvertising = {
                        scope.launch {
                            model.stop()
                            delay(220L)
                            model.start()
                        }
                    },
                    onShowAdvertisingHelp = { showAdvertisingHelp = true },
                    onOpenSystemBluetoothSettings = {
                        context.startActivity(
                            Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                    },
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .padding(top = 4.dp, bottom = 8.dp),
                )

                PetArea(
                    mode = mode,
                    personaState = personaState,
                    charactersRoot = model.charactersRoot,
                    builtinCharactersRoot = model.builtinCharactersRoot,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(petAreaDp),
                )

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .padding(horizontal = 14.dp)
                        .background(TerminalPalette.lcdDivider),
                )

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .padding(horizontal = 16.dp)
                        .padding(top = 10.dp)
                        .pointerInput(mode) {
                            // Accumulate the full drag so we page at most once
                            // per gesture — iOS semantics, not on each delta.
                            var accumulatedX = 0f
                            detectHorizontalDragGestures(
                                onDragStart = { accumulatedX = 0f },
                                onDragEnd = {
                                    if (accumulatedX > SWIPE_THRESHOLD_PX) {
                                        swipe(mode, -1,
                                            { petPage = wrap(petPage + it, PET_PAGES) },
                                            { infoPage = wrap(infoPage + it, INFO_PAGES.size) })
                                    } else if (accumulatedX < -SWIPE_THRESHOLD_PX) {
                                        swipe(mode, 1,
                                            { petPage = wrap(petPage + it, PET_PAGES) },
                                            { infoPage = wrap(infoPage + it, INFO_PAGES.size) })
                                    }
                                    accumulatedX = 0f
                                },
                                onDragCancel = { accumulatedX = 0f },
                            ) { _, drag -> accumulatedX += drag }
                        },
                ) {
                    when (mode) {
                        DisplayMode.NORMAL -> NormalBody(
                            snapshot = snapshot,
                            prompt = prompt,
                            responseSent = responseSent,
                            promptWaitedSeconds = waited,
                            parsedEntries = parsedEntries,
                            onApprove = { model.respondPermission(PermissionDecision.ONCE) },
                            onDeny = { model.respondPermission(PermissionDecision.DENY) },
                        )
                        DisplayMode.PET -> PetBody(
                            model = model,
                            stats = model.statsStore,
                            page = petPage,
                        )
                        DisplayMode.INFO -> InfoBody(
                            model = model,
                            persona = persona,
                            page = infoPage,
                            appStartMs = appStartMs,
                        )
                    }
                }

                BottomBar(
                    showPowerButton = showPowerButton,
                    onPressA = {
                        when {
                            deviceMenu.isAnyMenuVisible -> deviceMenu.advanceCursor()
                            mode == DisplayMode.NORMAL && prompt != null && !responseSent ->
                                model.respondPermission(PermissionDecision.ONCE)
                            else -> {
                                mode = mode.next()
                                if (mode == DisplayMode.PET) petPage = 0
                                if (mode == DisplayMode.INFO) infoPage = 0
                            }
                        }
                    },
                    onLongPressA = {
                        deviceMenu.toggleMenu()
                        onLongPressA()
                    },
                    onPressB = {
                        when {
                            deviceMenu.isAnyMenuVisible -> {
                                deviceMenu.applyCurrentSelection(
                                    cycleAsciiSpecies = {
                                        AsciiPetCycler.next(
                                            SharedPreferencesPersonaSelectionStore(context),
                                        )
                                    },
                                    onReset = { model.statsStore.reset() },
                                    onTurnOff = { /* handled by screenOff flip inside state */ },
                                    onDemo = { /* demo hook not wired on Android */ },
                                    onHelp = { /* help hook not wired on Android */ },
                                    onAbout = { /* about hook not wired on Android */ },
                                    onBluetoothChanged = { on ->
                                        if (on) model.start() else model.stop()
                                    },
                                )
                            }
                            mode == DisplayMode.NORMAL && prompt != null && !responseSent ->
                                model.respondPermission(PermissionDecision.DENY)
                            else -> when (mode) {
                                DisplayMode.PET -> petPage = wrap(petPage + 1, PET_PAGES)
                                DisplayMode.INFO -> infoPage = wrap(infoPage + 1, INFO_PAGES.size)
                                DisplayMode.NORMAL -> Unit
                            }
                        }
                    },
                    onPressPower = { deviceMenu.toggleScreen() },
                    onOpenLogs = onOpenLogs,
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .padding(top = 8.dp, bottom = 14.dp),
                )
            }
        }

        if (deviceMenu.isAnyMenuVisible && !deviceMenu.screenOff) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(TerminalPalette.lcdBg.copy(alpha = 0.92f)),
            ) {
                DeviceMenuOverlay(
                    state = deviceMenu,
                    bottomReservedHeight = 80.dp,
                )
            }
        }

        if (deviceMenu.screenOff) {
            ScreenOffMask(onWake = { deviceMenu.wakeScreen() })
        }

        if (showAdvertisingHelp) {
            AdvertisingHelpSheet(onDismiss = { showAdvertisingHelp = false })
        }
    }
}

enum class DisplayMode {
    NORMAL, PET, INFO;

    fun next(): DisplayMode = when (this) {
        NORMAL -> PET
        PET -> INFO
        INFO -> NORMAL
    }

    val label: String
        get() = when (this) {
            NORMAL -> "NORMAL"
            PET -> "PET"
            INFO -> "INFO"
        }
}


private inline fun wrap(value: Int, count: Int): Int =
    if (count <= 0) 0 else ((value % count) + count) % count

private inline fun swipe(
    mode: DisplayMode,
    step: Int,
    pagePet: (Int) -> Unit,
    pageInfo: (Int) -> Unit,
) {
    when (mode) {
        DisplayMode.PET -> pagePet(step)
        DisplayMode.INFO -> pageInfo(step)
        DisplayMode.NORMAL -> Unit
    }
}

private fun waitedSeconds(arrivedAtMs: Long?, nowMs: Long): Int {
    if (arrivedAtMs == null) return 0
    val elapsed = (nowMs - arrivedAtMs) / 1000L
    return if (elapsed < 0) 0 else elapsed.toInt()
}

private fun computePetAreaHeightDp(availableHeightPx: Float): androidx.compose.ui.unit.Dp {
    // 36% of the available height, clamped to [220, 320]dp — same envelope
    // iOS uses to keep ASCII/GIF renderers near 1:1.
    val densityIndependent = availableHeightPx / 3f
    val clamped = densityIndependent.coerceIn(220f, 320f)
    return clamped.dp
}

// MARK: - Top bar -----------------------------------------------------------

@Composable
private fun TopBar(
    connectionState: NusConnectionState,
    powerState: BluetoothPowerState,
    onOpenSettings: () -> Unit,
    onStartAdvertising: () -> Unit,
    onRestartAdvertising: () -> Unit,
    onShowAdvertisingHelp: () -> Unit,
    onOpenSystemBluetoothSettings: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            StatusIndicator(
                connectionState = connectionState,
                powerState = powerState,
                onStartAdvertising = onStartAdvertising,
                onOpenSystemBluetoothSettings = onOpenSystemBluetoothSettings,
            )
            Spacer(Modifier.weight(1f))
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .background(TerminalPalette.lcdPanel.copy(alpha = 0.7f), CircleShape)
                    .border(1.dp, TerminalPalette.inkDim.copy(alpha = 0.45f), CircleShape)
                    .clickable(onClick = onOpenSettings),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "SET",
                    color = TerminalPalette.ink,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    style = TextStyle(fontFamily = TerminalFonts.mono),
                )
            }
        }

        if (connectionState is NusConnectionState.Advertising) {
            AdvertisingActionBar(
                onRestartAdvertising = onRestartAdvertising,
                onShowHelp = onShowAdvertisingHelp,
            )
        }

        Text(
            text = "OpenVibble",
            color = TerminalPalette.ink,
            fontSize = 24.sp,
            fontWeight = FontWeight.ExtraBold,
            style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
        )
    }
}

@Composable
private fun StatusIndicator(
    connectionState: NusConnectionState,
    powerState: BluetoothPowerState,
    onStartAdvertising: () -> Unit,
    onOpenSystemBluetoothSettings: () -> Unit,
) {
    val label = statusLabel(connectionState, powerState)
    val color = statusColor(connectionState, powerState)
    val actionable = powerState == BluetoothPowerState.OFF ||
        (connectionState is NusConnectionState.Stopped && powerState == BluetoothPowerState.ON)
    val strokeColor = if (actionable) color.copy(alpha = 0.55f) else TerminalPalette.inkDim.copy(alpha = 0.4f)

    val onClick: (() -> Unit)? = when {
        powerState == BluetoothPowerState.OFF -> onOpenSystemBluetoothSettings
        connectionState is NusConnectionState.Stopped && powerState == BluetoothPowerState.ON -> onStartAdvertising
        else -> null
    }

    Row(
        modifier = Modifier
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.65f), shape = RoundedCornerShape(20.dp))
            .border(1.dp, strokeColor, RoundedCornerShape(20.dp))
            .let { if (onClick != null) it.clickable(onClick = onClick) else it }
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        BreathingLed(color = color)
        Text(
            text = label,
            color = TerminalPalette.ink,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun AdvertisingActionBar(
    onRestartAdvertising: () -> Unit,
    onShowHelp: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AdvertisingActionChip(
            icon = "R",
            text = stringResource(R.string.home_advertising_restart),
            stroke = TerminalPalette.accentSoft.copy(alpha = 0.55f),
            onClick = onRestartAdvertising,
        )
        AdvertisingActionChip(
            icon = "?",
            text = stringResource(R.string.home_advertising_help),
            stroke = TerminalPalette.inkDim.copy(alpha = 0.55f),
            onClick = onShowHelp,
        )
    }
}

@Composable
private fun AdvertisingActionChip(
    icon: String,
    text: String,
    stroke: Color,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.7f), RoundedCornerShape(20.dp))
            .border(1.dp, stroke, RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = icon,
            color = TerminalPalette.ink,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = text,
            color = TerminalPalette.ink,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun BreathingLed(color: Color) {
    val transition = rememberInfiniteTransition(label = "breathing-led")
    val alpha by transition.animateFloat(
        initialValue = 0.55f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "breathing-led-alpha",
    )
    Box(
        modifier = Modifier
            .size(10.dp)
            .background(color.copy(alpha = alpha), CircleShape),
    )
}

private fun statusLabel(connection: NusConnectionState, power: BluetoothPowerState): String = when {
    power == BluetoothPowerState.OFF -> "BLE:off"
    power == BluetoothPowerState.UNSUPPORTED -> "BLE:unsupported"
    connection is NusConnectionState.Connected -> if (connection.centralCount > 1) {
        "BLE:conn(${connection.centralCount})"
    } else {
        "BLE:conn"
    }
    connection is NusConnectionState.Advertising -> "BLE:adv"
    else -> "BLE:idle"
}

private fun statusColor(connection: NusConnectionState, power: BluetoothPowerState): Color = when {
    power == BluetoothPowerState.OFF || power == BluetoothPowerState.UNSUPPORTED -> TerminalPalette.bad
    connection is NusConnectionState.Connected -> TerminalPalette.good
    connection is NusConnectionState.Advertising -> TerminalPalette.accentSoft
    else -> TerminalPalette.inkDim
}

// MARK: - Pet area ---------------------------------------------------------

@Composable
private fun PetArea(
    mode: DisplayMode,
    personaState: PersonaState,
    charactersRoot: java.io.File,
    builtinCharactersRoot: java.io.File,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val selection = remember { SharedPreferencesPersonaSelectionStore(context).load() }
    val speciesIdx = remember(selection) { resolveSpeciesIdx(selection) }
    // iOS ports render installed/builtin personas as GIFs; ASCII fallbacks
    // only kick in for AsciiCat/AsciiSpecies selections or when the manifest
    // can't be found on disk.
    val installed = remember(selection, charactersRoot, builtinCharactersRoot) {
        resolveInstalledPersona(selection, charactersRoot, builtinCharactersRoot)
    }
    Box(modifier = modifier.background(TerminalPalette.lcdPanel)) {
        if (installed != null) {
            GifBuddyView(
                persona = installed,
                state = personaState,
                modifier = Modifier
                    .align(Alignment.Center)
                    .widthIn(max = 200.dp)
                    .heightIn(max = 200.dp)
                    .padding(horizontal = 24.dp),
            )
        } else {
            AsciiBuddyView(
                state = personaState,
                speciesIdx = speciesIdx,
                modifier = Modifier
                    .align(Alignment.Center)
                    .widthIn(max = 200.dp)
                    .heightIn(max = 200.dp)
                    .padding(horizontal = 24.dp),
            )
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 6.dp)
                .align(Alignment.TopCenter),
        ) {
            Text(
                text = mode.label,
                color = TerminalPalette.inkDim,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = personaState.slug.uppercase(),
                color = TerminalPalette.inkDim,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
            )
        }
    }
}

private fun resolveSpeciesIdx(selection: PersonaSpeciesId): Int = when (selection) {
    is PersonaSpeciesId.AsciiCat -> SpeciesRegistry.defaultIdx()
    is PersonaSpeciesId.AsciiSpecies -> selection.idx
    is PersonaSpeciesId.Builtin -> SpeciesRegistry.defaultIdx()
    is PersonaSpeciesId.Installed -> SpeciesRegistry.defaultIdx()
}

/**
 * Resolves the current persona selection to an on-disk [InstalledPersona] or
 * null if the selection isn't a GIF-backed pack (ASCII track) or the pack's
 * manifest can't be located. `Builtin` looks in [builtinCharactersRoot] (app
 * assets bootstrapped on first launch); `Installed` looks in [charactersRoot]
 * (user-transferred packs).
 */
private fun resolveInstalledPersona(
    selection: PersonaSpeciesId,
    charactersRoot: java.io.File,
    builtinCharactersRoot: java.io.File,
): com.openvibble.persona.InstalledPersona? {
    val (name, root) = when (selection) {
        is PersonaSpeciesId.Builtin -> selection.name to builtinCharactersRoot
        is PersonaSpeciesId.Installed -> selection.name to charactersRoot
        else -> return null
    }
    return com.openvibble.persona.PersonaCatalog(root).load(name)
}

// MARK: - Mode bodies ------------------------------------------------------

// MARK: - Bottom bar -------------------------------------------------------

@Composable
private fun BottomBar(
    showPowerButton: Boolean,
    onPressA: () -> Unit,
    onLongPressA: () -> Unit,
    onPressB: () -> Unit,
    onPressPower: () -> Unit,
    onOpenLogs: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        HandheldButton(label = "A", accent = TerminalPalette.good, onPress = onPressA, onLongPress = onLongPressA)
        HandheldButton(label = "B", accent = TerminalPalette.bad, onPress = onPressB, onLongPress = null)
        Spacer(Modifier.weight(1f))
        if (showPowerButton) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(TerminalPalette.lcdPanel.copy(alpha = 0.85f), CircleShape)
                    .border(1.dp, TerminalPalette.inkDim.copy(alpha = 0.5f), CircleShape)
                    .clickable(onClick = onPressPower),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "PWR",
                    color = TerminalPalette.accentSoft,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    style = TextStyle(fontFamily = TerminalFonts.mono),
                )
            }
        }
        Row(
            modifier = Modifier
                .background(TerminalPalette.lcdPanel.copy(alpha = 0.85f), RoundedCornerShape(10.dp))
                .border(1.dp, TerminalPalette.inkDim.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                .clickable(onClick = onOpenLogs)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Text(
                text = stringResource(R.string.home_log),
                color = TerminalPalette.ink,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
            )
        }
    }
}

@Composable
private fun HandheldButton(
    label: String,
    accent: Color,
    onPress: () -> Unit,
    onLongPress: (() -> Unit)?,
) {
    Box(
        modifier = Modifier
            .size(54.dp)
            .background(accent, CircleShape)
            .border(2.dp, Color.Black.copy(alpha = 0.6f), CircleShape)
            .pointerInput(onLongPress) {
                detectTapGestures(
                    onTap = { onPress() },
                    onLongPress = { onLongPress?.invoke() },
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Black,
        )
    }
}

// MARK: - NORMAL body ------------------------------------------------------

@Composable
private fun NormalBody(
    snapshot: com.openvibble.runtime.BridgeSnapshot,
    prompt: PromptRequest?,
    responseSent: Boolean,
    promptWaitedSeconds: Int,
    parsedEntries: List<String>,
    onApprove: () -> Unit,
    onDeny: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (prompt != null) {
            PromptPanel(
                prompt = prompt,
                waitedSeconds = promptWaitedSeconds,
                responseSent = responseSent,
                onApprove = onApprove,
                onDeny = onDeny,
            )
        } else {
            StatusLine(snapshot = snapshot)
        }

        ParsedLogList(entries = parsedEntries)
    }
}

/**
 * NORMAL tab's "解析后日志" — mirrors iOS HomeScreen parsedLogRow.
 * Caps at 64 entries (same as iOS prefix) so the list stays snappy. Raw BLE
 * wire events intentionally live behind HomeLogSheet, not here.
 */
@Composable
private fun ParsedLogList(entries: List<String>) {
    if (entries.isEmpty()) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                text = stringResource(R.string.home_log_empty),
                color = TerminalPalette.inkDim.copy(alpha = 0.6f),
                fontSize = 11.sp,
                style = TextStyle(fontFamily = TerminalFonts.mono),
                textAlign = TextAlign.Center,
            )
        }
        return
    }
    val lines = remember(entries) { entries.take(64).map(::parseLogLine) }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        items(lines) { line -> ParsedLogRow(line) }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ParsedLogRow(line: LogLine) {
    val clipboard = LocalClipboardManager.current
    val haptic = LocalHapticFeedback.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(
                onClick = {},
                onLongClick = {
                    clipboard.setText(AnnotatedString("${line.time} ${line.message}"))
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                },
            ),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = line.time,
            color = TerminalPalette.inkDim,
            fontSize = 10.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.widthIn(min = 58.dp),
        )
        Text(
            text = line.message,
            color = TerminalPalette.ink,
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

internal data class LogLine(val time: String, val message: String)

/**
 * Parses a parsedEntries line into time + message. The bridge already prefixes
 * entries with `HH:mm:ss ` in most cases, but fall back to the wall clock
 * when the prefix is missing (same defensive split as iOS).
 */
internal fun parseLogLine(entry: String): LogLine {
    val spaceIdx = entry.indexOf(' ')
    if (spaceIdx > 0) {
        val head = entry.substring(0, spaceIdx)
        if (head.contains(':')) {
            return LogLine(time = head, message = entry.substring(spaceIdx + 1))
        }
    }
    return LogLine(time = currentClock(), message = entry)
}

private fun currentClock(): String {
    val f = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.US)
    return f.format(java.util.Date())
}

@Composable
private fun StatusLine(snapshot: com.openvibble.runtime.BridgeSnapshot) {
    val msg = if (snapshot.msg.isBlank()) stringResource(R.string.home_status_waiting_for_claude) else snapshot.msg
    val glyph = rememberSpinGlyph()
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                text = msg,
                color = TerminalPalette.ink,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                style = TextStyle(fontFamily = TerminalFonts.mono),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            Text(
                text = glyph,
                color = TerminalPalette.accentSoft,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                style = TextStyle(fontFamily = TerminalFonts.mono),
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            StatusPill(label = stringResource(R.string.home_metric_sessions), value = snapshot.total.toString())
            StatusPill(label = stringResource(R.string.home_metric_running), value = snapshot.running.toString())
            StatusPill(label = stringResource(R.string.home_metric_waiting), value = snapshot.waiting.toString())
            StatusPill(label = stringResource(R.string.home_metric_tok_day), value = formatTokensShort(snapshot.tokensToday))
        }
    }
}

/**
 * Mirrors iOS's `spinTimer` on HomeScreen.swift:855 — a 450ms cycle through
 * `· • · •` that sits next to the status message so the user can tell the app
 * is alive even when nothing's arriving from Claude. Exposed as its own
 * composable so recomposition is scoped to the glyph cell.
 */
@Composable
private fun rememberSpinGlyph(): String {
    var phase by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(SPIN_PERIOD_MS)
            phase = (phase + 1) % SPIN_GLYPHS.size
        }
    }
    return SPIN_GLYPHS[phase]
}

private val SPIN_GLYPHS = listOf(".", "*", ".", "*")
private const val SPIN_PERIOD_MS = 450L

/**
 * Min horizontal drag (raw pixels, not dp) before a swipe counts as a page
 * flip. iOS uses 30pt; at 3x density that is ~90px, so ~60–90px is a natural
 * envelope. We land at 80 for a clear intentional-swipe feel.
 */
private const val SWIPE_THRESHOLD_PX = 80f

@Composable
private fun StatusPill(label: String, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            color = TerminalPalette.inkDim,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = value,
            color = TerminalPalette.ink,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun PromptPanel(
    prompt: PromptRequest,
    waitedSeconds: Int,
    responseSent: Boolean,
    onApprove: () -> Unit,
    onDeny: () -> Unit,
) {
    val timerColor = if (waitedSeconds >= 10) TerminalPalette.accent else TerminalPalette.accentSoft
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.9f), RoundedCornerShape(10.dp))
            .border(1.dp, TerminalPalette.accent.copy(alpha = 0.6f), RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = stringResource(R.string.home_prompt_waited, waitedSeconds),
            color = timerColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = prompt.tool,
            color = TerminalPalette.ink,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (prompt.hint.isNotEmpty()) {
            Text(
                text = prompt.hint,
                color = TerminalPalette.inkDim,
                fontSize = 11.sp,
                style = TextStyle(fontFamily = TerminalFonts.mono),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            if (responseSent) {
                Text(
                    text = stringResource(R.string.home_prompt_sent),
                    color = TerminalPalette.good,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
                )
            } else {
                PromptActionChip(label = stringResource(R.string.home_prompt_approve), key = "A", tint = TerminalPalette.good, onClick = onApprove)
                PromptActionChip(label = stringResource(R.string.home_prompt_deny), key = "B", tint = TerminalPalette.bad, onClick = onDeny)
            }
        }
    }
}

@Composable
private fun PromptActionChip(label: String, key: String, tint: Color, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .background(tint.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
            .border(1.dp, tint.copy(alpha = 0.7f), RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = "[$key]",
            color = tint,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = label,
            color = TerminalPalette.ink,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
        )
    }
}

private fun formatTokensShort(n: Int): String = when {
    n >= 1_000_000 -> "${n / 1_000_000}M"
    n >= 1_000 -> "${n / 1_000}K"
    else -> n.toString()
}
