// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.protocol

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.descriptors.element
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonElement

@Serializable
data class BridgeAck(
    val ack: String,
    val ok: Boolean,
    val n: Int? = null,
    val error: String? = null,
    val data: JsonElement? = null,
)

/** Envelope `{"time":[epochSeconds, timezoneOffsetSeconds]}`. */
@Serializable(with = TimeSync.Companion::class)
data class TimeSync(
    val epochSeconds: Long,
    val timezoneOffsetSeconds: Int,
) {
    companion object : KSerializer<TimeSync> {
        override val descriptor: SerialDescriptor =
            buildClassSerialDescriptor("TimeSync") {
                element<List<Long>>("time")
            }

        override fun deserialize(decoder: Decoder): TimeSync {
            val element = decoder.decodeJsonElementCompat()
            val arr = element.asJsonObject()["time"]?.asJsonArray()
                ?: error("TimeSync missing 'time' array")
            val epoch = arr[0].asJsonPrimitive().content.toLong()
            val tz = arr[1].asJsonPrimitive().content.toInt()
            return TimeSync(epoch, tz)
        }

        override fun serialize(encoder: Encoder, value: TimeSync) {
            val obj = kotlinx.serialization.json.buildJsonObject {
                put(
                    "time",
                    kotlinx.serialization.json.buildJsonArray {
                        add(kotlinx.serialization.json.JsonPrimitive(value.epochSeconds))
                        add(kotlinx.serialization.json.JsonPrimitive(value.timezoneOffsetSeconds))
                    },
                )
            }
            encoder.encodeJsonElementCompat(obj)
        }
    }
}

@Serializable
data class HeartbeatPrompt(
    val id: String,
    val tool: String? = null,
    val hint: String? = null,
)

@Serializable
data class HeartbeatSnapshot(
    val total: Int,
    val running: Int,
    val waiting: Int,
    val msg: String,
    val entries: List<String> = emptyList(),
    val tokens: Int? = null,
    @SerialName("tokens_today") val tokensToday: Int? = null,
    val prompt: HeartbeatPrompt? = null,
    val completed: Boolean? = null,
)

@Serializable
data class TurnEvent(
    val evt: String,
    val role: String,
    val content: List<JsonElement> = emptyList(),
)

@Serializable
enum class PermissionDecision {
    @SerialName("once") ONCE,
    @SerialName("deny") DENY,
}

@Serializable
data class PermissionCommand(
    val cmd: String = "permission",
    val id: String,
    val decision: PermissionDecision,
)

@Serializable
data class NameCommand(val cmd: String = "name", val name: String)

@Serializable
data class OwnerCommand(val cmd: String = "owner", val name: String)

@Serializable
data class StatusCommand(val cmd: String = "status")

@Serializable
data class UnpairCommand(val cmd: String = "unpair")

@Serializable
data class CharBeginCommand(val cmd: String = "char_begin", val name: String, val total: Int)

@Serializable
data class FileCommand(val cmd: String = "file", val path: String, val size: Int)

@Serializable
data class ChunkCommand(val cmd: String = "chunk", val d: String) {
    companion object {
        fun fromBase64(base64: String): ChunkCommand = ChunkCommand(d = base64)
    }
}

@Serializable
data class FileEndCommand(val cmd: String = "file_end")

@Serializable
data class CharEndCommand(val cmd: String = "char_end")

@Serializable
data class SpeciesCommand(val cmd: String = "species", val idx: Int)

sealed class BridgeCommand {
    data object Status : BridgeCommand()
    data class Name(val name: String) : BridgeCommand()
    data class Owner(val name: String) : BridgeCommand()
    data object Unpair : BridgeCommand()
    data class CharBegin(val name: String, val total: Int) : BridgeCommand()
    data class File(val path: String, val size: Int) : BridgeCommand()
    data class Chunk(val base64: String) : BridgeCommand()
    data object FileEnd : BridgeCommand()
    data object CharEnd : BridgeCommand()
    data class Permission(val id: String, val decision: PermissionDecision) : BridgeCommand()
    data class Species(val idx: Int) : BridgeCommand()
    data class Unknown(val cmd: String) : BridgeCommand()
}

sealed class BridgeInboundMessage {
    data class Heartbeat(val snapshot: HeartbeatSnapshot) : BridgeInboundMessage()
    data class Turn(val event: TurnEvent) : BridgeInboundMessage()
    data class Time(val sync: TimeSync) : BridgeInboundMessage()
    data class Command(val command: BridgeCommand) : BridgeInboundMessage()
}

class BridgeProtocolException(message: String) : RuntimeException(message)
