// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

import com.openvibble.persona.PersonaSelection
import com.openvibble.persona.PersonaSelectionStore
import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.protocol.BridgeAck
import com.openvibble.protocol.BridgeCommand
import com.openvibble.protocol.BridgeInboundMessage
import com.openvibble.protocol.NDJSONCodec
import com.openvibble.protocol.PermissionCommand
import com.openvibble.protocol.PermissionDecision
import com.openvibble.storage.CharacterTransferStore
import com.openvibble.storage.TransferProgress
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull

data class PromptRequest(val id: String, val tool: String, val hint: String)

data class BatterySample(
    val percent: Int,
    val millivolts: Int = 0,
    val milliamps: Int = 0,
    val usb: Boolean = false,
)

data class StatsSample(
    val approvals: Int,
    val denials: Int,
    val velocityMedianSeconds: Int,
    val napSeconds: Int,
    val level: Int,
)

data class StatusSample(val battery: BatterySample, val stats: StatsSample)

data class BridgeSnapshot(
    val total: Int = 0,
    val running: Int = 0,
    val waiting: Int = 0,
    val msg: String = "",
    val entries: List<String> = emptyList(),
    val tokens: Int = 0,
    val tokensToday: Int = 0,
    val ownerName: String = "",
    val deviceName: String = "Claude-iOS",
    val lastTurnRole: String = "",
    val lastTurnPreview: String = "",
) {
    companion object {
        val empty: BridgeSnapshot = BridgeSnapshot()
    }
}

data class FilesystemCapacity(val free: Long, val total: Long) {
    companion object { val unknown = FilesystemCapacity(0L, 0L) }
}

fun interface FilesystemCapacityProvider {
    fun read(directory: File): FilesystemCapacity
}

/**
 * Runtime that owns the conversation with Claude Desktop. It is deliberately
 * platform-agnostic — the Android layer feeds it lines from the BLE GATT
 * server (BuddyPeripheralService) and forwards returned lines back.
 *
 * Behavior matches iOS BridgeRuntime 1:1: heartbeat snapshot bookkeeping,
 * optimistic prompt latching on permission answer, species selection hooks,
 * character pack ingestion.
 */
class BridgeRuntime(
    initialSnapshot: BridgeSnapshot = BridgeSnapshot.empty,
    private val transferStore: CharacterTransferStore,
    private val personaSelection: PersonaSelectionStore,
    private val filesystemCapacityProvider: FilesystemCapacityProvider = FilesystemCapacityProvider { FilesystemCapacity.unknown },
    private val nowProvider: () -> Long = { System.currentTimeMillis() },
) {
    private val startEpochMs: Long = nowProvider()

    private val _snapshot = MutableStateFlow(initialSnapshot)
    val snapshot: StateFlow<BridgeSnapshot> = _snapshot.asStateFlow()

    private val _prompt = MutableStateFlow<PromptRequest?>(null)
    val prompt: StateFlow<PromptRequest?> = _prompt.asStateFlow()

    private val _transferProgress = MutableStateFlow(TransferProgress.idle)
    val transferProgress: StateFlow<TransferProgress> = _transferProgress.asStateFlow()

    /**
     * Most recent prompt id we already answered via respondPermission. The
     * desktop needs a round-trip before its next heartbeat reflects the
     * response, and during that window ingestLine would otherwise re-seat
     * the same prompt and make the UI bounce.
     */
    private var lastAnsweredPromptId: String? = null
    private var lastStatusSample: StatusSample? = null

    var onCharacterInstalled: ((String) -> Unit)? = null
    var onSpeciesChanged: ((Int) -> Unit)? = null
    var onTaskCompleted: (() -> Unit)? = null

    val charactersRoot: File get() = transferStore.charactersRoot

    fun updateStatusSample(sample: StatusSample) {
        lastStatusSample = sample
    }

    fun ingestLine(line: String): List<String> {
        val message = try {
            NDJSONCodec.decodeInboundLine(line)
        } catch (_: Throwable) {
            return emptyList()
        }

        return when (message) {
            is BridgeInboundMessage.Heartbeat -> {
                val hb = message.snapshot
                val current = _snapshot.value
                _snapshot.value = current.copy(
                    total = hb.total,
                    running = hb.running,
                    waiting = hb.waiting,
                    msg = hb.msg,
                    entries = hb.entries,
                    tokens = hb.tokens ?: current.tokens,
                    tokensToday = hb.tokensToday ?: current.tokensToday,
                )
                val prompt = hb.prompt
                if (prompt != null) {
                    if (prompt.id == lastAnsweredPromptId) {
                        _prompt.value = null
                    } else {
                        _prompt.value = PromptRequest(
                            id = prompt.id,
                            tool = prompt.tool.orEmpty(),
                            hint = prompt.hint.orEmpty(),
                        )
                        lastAnsweredPromptId = null
                    }
                } else {
                    _prompt.value = null
                    lastAnsweredPromptId = null
                }
                if (hb.completed == true) onTaskCompleted?.invoke()
                emptyList()
            }

            is BridgeInboundMessage.Turn -> {
                val turn = message.event
                val preview = turn.content.firstOrNull()?.let { describeJson(it) }.orEmpty()
                _snapshot.value = _snapshot.value.copy(
                    lastTurnRole = turn.role,
                    lastTurnPreview = preview,
                )
                emptyList()
            }

            is BridgeInboundMessage.Time -> emptyList()

            is BridgeInboundMessage.Command -> handleCommand(message.command)
        }
    }

    fun handleCommand(command: BridgeCommand): List<String> = when (command) {
        BridgeCommand.Status -> listOf(encodeAck(makeStatusAck()))

        is BridgeCommand.Name -> {
            val name = command.name
            if (name.isNotEmpty()) {
                _snapshot.value = _snapshot.value.copy(deviceName = name)
            }
            listOf(
                encodeAck(
                    BridgeAck(
                        ack = "name",
                        ok = name.isNotEmpty(),
                        n = 0,
                        error = if (name.isEmpty()) "name required" else null,
                    )
                )
            )
        }

        is BridgeCommand.Owner -> {
            val name = command.name
            _snapshot.value = _snapshot.value.copy(ownerName = name)
            listOf(
                encodeAck(
                    BridgeAck(
                        ack = "owner",
                        ok = name.isNotEmpty(),
                        n = 0,
                        error = if (name.isEmpty()) "owner required" else null,
                    )
                )
            )
        }

        BridgeCommand.Unpair -> {
            _prompt.value = null
            lastAnsweredPromptId = null
            transferStore.reset()
            _transferProgress.value = transferStore.progress
            listOf(
                encodeAck(
                    BridgeAck(
                        ack = "unpair",
                        ok = true,
                        n = 0,
                        error = "android_bond_reset_requires_system_forget",
                    )
                )
            )
        }

        is BridgeCommand.CharBegin -> {
            val ack = transferStore.beginCharacter(command.name, command.total)
            _transferProgress.value = transferStore.progress
            listOf(encodeAck(ack))
        }

        is BridgeCommand.File -> {
            val ack = transferStore.openFile(command.path, command.size)
            _transferProgress.value = transferStore.progress
            listOf(encodeAck(ack))
        }

        is BridgeCommand.Chunk -> {
            val ack = transferStore.appendChunk(command.base64)
            _transferProgress.value = transferStore.progress
            listOf(encodeAck(ack))
        }

        BridgeCommand.FileEnd -> {
            val ack = transferStore.closeFile()
            _transferProgress.value = transferStore.progress
            listOf(encodeAck(ack))
        }

        BridgeCommand.CharEnd -> {
            val installedName = transferStore.progress.characterName
            val ack = transferStore.finishCharacter()
            _transferProgress.value = transferStore.progress
            if (ack.ok && installedName.isNotEmpty()) {
                onCharacterInstalled?.invoke(installedName)
            }
            listOf(encodeAck(ack))
        }

        is BridgeCommand.Permission -> emptyList()

        is BridgeCommand.Species -> {
            val idx = command.idx
            when {
                idx == PersonaSpeciesCatalog.GIF_SENTINEL -> {
                    val current = personaSelection.load()
                    if (current !is PersonaSpeciesId.Builtin && current !is PersonaSpeciesId.Installed) {
                        personaSelection.save(PersonaSelection.defaultSpecies)
                    }
                    onSpeciesChanged?.invoke(idx)
                    listOf(encodeAck(BridgeAck(ack = "species", ok = true, n = 0)))
                }
                !PersonaSpeciesCatalog.isValid(idx) -> {
                    listOf(
                        encodeAck(
                            BridgeAck(ack = "species", ok = false, n = 0, error = "invalid idx")
                        )
                    )
                }
                else -> {
                    personaSelection.save(PersonaSpeciesId.AsciiSpecies(idx))
                    onSpeciesChanged?.invoke(idx)
                    listOf(encodeAck(BridgeAck(ack = "species", ok = true, n = 0)))
                }
            }
        }

        is BridgeCommand.Unknown ->
            listOf(encodeAck(BridgeAck(ack = command.cmd, ok = false, n = 0, error = "unsupported command")))
    }

    fun respondPermission(decision: PermissionDecision): String? {
        val current = _prompt.value ?: return null
        val command = PermissionCommand(id = current.id, decision = decision)
        val line = runCatching { NDJSONCodec.encodeLine(command) }.getOrNull() ?: return null
        // Optimistically clear so the UI collapses without waiting for the
        // next heartbeat round-trip. Retain the id so subsequent heartbeats
        // carrying the same prompt don't re-seat it.
        lastAnsweredPromptId = current.id
        _prompt.value = null
        return line
    }

    private fun makeStatusAck(): BridgeAck {
        val transfer = transferStore.progress
        _transferProgress.value = transfer

        val snap = _snapshot.value
        val sample = lastStatusSample
        val battery = sample?.battery ?: BatterySample(percent = 100, millivolts = 4000, milliamps = 0, usb = true)
        val stats = sample?.stats ?: StatsSample(
            approvals = snap.running,
            denials = snap.waiting,
            velocityMedianSeconds = snap.total,
            napSeconds = 0,
            level = (snap.tokens / 50_000),
        )

        val uptimeSeconds = ((nowProvider() - startEpochMs) / 1000L).toInt()
        val capacity = filesystemCapacityProvider.read(transferStore.charactersRoot)

        val payload = buildJsonObject {
            put("name", JsonPrimitive(snap.deviceName))
            put("owner", JsonPrimitive(snap.ownerName))
            put("sec", JsonPrimitive(false))
            put(
                "bat",
                buildJsonObject {
                    put("pct", JsonPrimitive(battery.percent))
                    put("mV", JsonPrimitive(battery.millivolts))
                    put("mA", JsonPrimitive(battery.milliamps))
                    put("usb", JsonPrimitive(battery.usb))
                },
            )
            put(
                "sys",
                buildJsonObject {
                    put("up", JsonPrimitive(uptimeSeconds))
                    put("heap", JsonPrimitive(0))
                    put("fsFree", JsonPrimitive(capacity.free))
                    put("fsTotal", JsonPrimitive(capacity.total))
                },
            )
            put(
                "stats",
                buildJsonObject {
                    put("appr", JsonPrimitive(stats.approvals))
                    put("deny", JsonPrimitive(stats.denials))
                    put("vel", JsonPrimitive(stats.velocityMedianSeconds))
                    put("nap", JsonPrimitive(stats.napSeconds))
                    put("lvl", JsonPrimitive(stats.level))
                },
            )
            put(
                "xfer",
                buildJsonObject {
                    put("active", JsonPrimitive(transfer.isActive))
                    put("total", JsonPrimitive(transfer.totalBytes))
                    put("written", JsonPrimitive(transfer.writtenBytes))
                },
            )
        }

        return BridgeAck(ack = "status", ok = true, n = 0, data = payload)
    }

    private fun encodeAck(ack: BridgeAck): String =
        runCatching { NDJSONCodec.encodeLine(ack) }.getOrElse { "{\"ack\":\"invalid\",\"ok\":false}\n" }

    private fun describeJson(value: JsonElement): String = when (value) {
        is JsonPrimitive -> when {
            value.isString -> value.content
            else -> value.contentOrNull ?: "null"
        }
        is JsonObject -> "{...}"
        is JsonArray -> "[...]"
        JsonNull -> "null"
    }
}
