// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

@Serializable
data class PersonaPalette(
    val body: String? = null,
    val bg: String? = null,
    val text: String? = null,
    val textDim: String? = null,
    val ink: String? = null,
)

enum class PersonaMode(val raw: String) {
    GIF("gif"),
    TEXT("text");

    companion object {
        fun fromRaw(raw: String?): PersonaMode = when (raw) {
            "text" -> TEXT
            else -> GIF
        }
    }
}

@Serializable(with = StateFrames.Companion::class)
sealed class StateFrames {
    abstract val filenames: List<String>

    data class Single(val name: String) : StateFrames() {
        override val filenames: List<String> get() = listOf(name)
    }

    data class Variants(val names: List<String>) : StateFrames() {
        override val filenames: List<String> get() = names
    }

    data class Text(val frames: List<String>, val delayMs: Int) : StateFrames() {
        override val filenames: List<String> get() = emptyList()
    }

    companion object : KSerializer<StateFrames> {
        override val descriptor: SerialDescriptor =
            buildClassSerialDescriptor("StateFrames")

        override fun deserialize(decoder: Decoder): StateFrames {
            val element = (decoder as JsonDecoder).decodeJsonElement()
            return when (element) {
                is JsonPrimitive -> {
                    if (!element.isString) error("StateFrames primitive must be a string, got ${element.content}")
                    Single(element.content)
                }
                is JsonArray -> Variants(
                    element.map {
                        val p = it.jsonPrimitive
                        if (!p.isString) error("StateFrames array element must be a string")
                        p.content
                    }
                )
                is JsonObject -> {
                    val frames = element["frames"]?.jsonArray?.map {
                        val p = it.jsonPrimitive
                        if (!p.isString) error("frames element must be a string")
                        p.content
                    } ?: error("StateFrames object missing 'frames'")
                    val delay = element["delay_ms"]?.jsonPrimitive?.intOrNull
                        ?: element["delay"]?.jsonPrimitive?.intOrNull
                        ?: 200
                    Text(frames, delay)
                }
            }
        }

        override fun serialize(encoder: Encoder, value: StateFrames) {
            val jsonEncoder = encoder as JsonEncoder
            val element: JsonElement = when (value) {
                is Single -> JsonPrimitive(value.name)
                is Variants -> JsonArray(value.names.map { JsonPrimitive(it) })
                is Text -> buildJsonObject {
                    put("frames", JsonArray(value.frames.map { JsonPrimitive(it) }))
                    put("delay_ms", JsonPrimitive(value.delayMs))
                }
            }
            jsonEncoder.encodeJsonElement(element)
        }
    }
}

data class PersonaManifest(
    val name: String,
    val mode: PersonaMode,
    val colors: PersonaPalette,
    val states: Map<String, StateFrames>,
) {
    fun framesFor(slug: String): StateFrames? = states[slug]

    companion object {
        private val json = Json {
            ignoreUnknownKeys = true
            isLenient = true
        }

        fun fromJson(text: String): PersonaManifest? {
            val element = try {
                json.parseToJsonElement(text) as? JsonObject ?: return null
            } catch (_: Throwable) {
                return null
            }
            val name = element["name"]?.jsonPrimitive?.content ?: return null
            val mode = PersonaMode.fromRaw(element["mode"]?.jsonPrimitive?.content)

            val colors = element["colors"]?.let {
                runCatching { json.decodeFromJsonElement(PersonaPalette.serializer(), it) }.getOrNull()
            } ?: PersonaPalette()

            val states = element["states"]?.let { raw ->
                runCatching {
                    json.decodeFromJsonElement(
                        MapSerializer(String.serializer(), StateFrames),
                        raw,
                    )
                }.getOrNull()
            } ?: emptyMap()

            return PersonaManifest(name, mode, colors, states)
        }
    }
}
