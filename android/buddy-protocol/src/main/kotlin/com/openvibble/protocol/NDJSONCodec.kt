// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.protocol

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Newline-delimited JSON framer. Buffers incoming byte chunks and yields
 * complete UTF-8 lines as they cross `\n` boundaries. Mirrors iOS NDJSONLineFramer.
 */
class NDJSONLineFramer {
    private val buffer = ArrayList<Byte>(512)

    fun ingest(chunk: ByteArray): List<String> {
        if (chunk.isEmpty()) return emptyList()
        buffer.ensureCapacity(buffer.size + chunk.size)
        for (b in chunk) buffer.add(b)

        val lines = mutableListOf<String>()
        var start = 0
        for (i in buffer.indices) {
            if (buffer[i] == NEWLINE) {
                if (i > start) {
                    val bytes = ByteArray(i - start)
                    for (j in 0 until i - start) bytes[j] = buffer[start + j]
                    val line = String(bytes, Charsets.UTF_8).trim()
                    if (line.isNotEmpty()) lines.add(line)
                }
                start = i + 1
            }
        }
        if (start > 0) {
            val remaining = buffer.size - start
            val tail = ArrayList<Byte>(remaining).apply {
                for (k in 0 until remaining) add(buffer[start + k])
            }
            buffer.clear()
            buffer.addAll(tail)
        }
        return lines
    }

    fun reset() {
        buffer.clear()
    }

    private companion object {
        const val NEWLINE: Byte = 0x0A
    }
}

object NDJSONCodec {
    val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = false
    }

    inline fun <reified T> encodeLine(value: T): String = json.encodeToString(value) + "\n"

    fun decodeInboundLine(line: String): BridgeInboundMessage {
        val element = try {
            json.parseToJsonElement(line)
        } catch (t: Throwable) {
            throw BridgeProtocolException("Invalid JSON: ${t.message}")
        }
        if (element !is JsonObject) throw BridgeProtocolException("Envelope must be object")

        if ("time" in element) {
            return BridgeInboundMessage.Time(json.decodeFromJsonElement(TimeSync.serializer(), element))
        }

        element["evt"]?.jsonPrimitive?.contentOrNull?.let { evt ->
            if (evt == "turn") {
                return BridgeInboundMessage.Turn(json.decodeFromJsonElement(TurnEvent.serializer(), element))
            }
        }

        val hasHeartbeatShape = listOf("total", "running", "waiting", "msg", "entries")
            .all { it in element }
        if (hasHeartbeatShape) {
            return BridgeInboundMessage.Heartbeat(
                json.decodeFromJsonElement(HeartbeatSnapshot.serializer(), element)
            )
        }

        val cmd = element["cmd"]?.jsonPrimitive?.contentOrNull
            ?: throw BridgeProtocolException("Unknown envelope without cmd")

        return BridgeInboundMessage.Command(parseCommand(cmd, element))
    }

    private fun parseCommand(cmd: String, element: JsonObject): BridgeCommand {
        fun string(key: String): String =
            element[key]?.jsonPrimitive?.contentOrNull.orEmpty()
        fun int(key: String): Int =
            element[key]?.jsonPrimitive?.intOrNull ?: 0

        return when (cmd) {
            "status" -> BridgeCommand.Status
            "name" -> BridgeCommand.Name(string("name"))
            "owner" -> BridgeCommand.Owner(string("name"))
            "unpair" -> BridgeCommand.Unpair
            "char_begin" -> BridgeCommand.CharBegin(string("name"), int("total"))
            "file" -> BridgeCommand.File(string("path"), int("size"))
            "chunk" -> BridgeCommand.Chunk(string("d"))
            "file_end" -> BridgeCommand.FileEnd
            "char_end" -> BridgeCommand.CharEnd
            "permission" -> {
                val decisionRaw = string("decision")
                val decision = when (decisionRaw) {
                    "once" -> PermissionDecision.ONCE
                    else -> PermissionDecision.DENY
                }
                BridgeCommand.Permission(string("id"), decision)
            }
            "species" -> {
                val raw = element["idx"]?.jsonPrimitive
                val idx = raw?.intOrNull
                    ?: raw?.contentOrNull?.toIntOrNull()
                    ?: -1
                BridgeCommand.Species(idx)
            }
            else -> BridgeCommand.Unknown(cmd)
        }
    }
}
