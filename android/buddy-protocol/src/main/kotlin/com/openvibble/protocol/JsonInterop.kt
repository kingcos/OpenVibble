// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.protocol

import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

internal fun Decoder.decodeJsonElementCompat(): JsonElement =
    (this as JsonDecoder).decodeJsonElement()

internal fun Encoder.encodeJsonElementCompat(element: JsonElement) {
    (this as JsonEncoder).encodeJsonElement(element)
}

internal fun JsonElement.asJsonObject(): JsonObject =
    this as? JsonObject ?: error("Expected JSON object, got ${this::class.simpleName}")

internal fun JsonElement.asJsonArray(): JsonArray =
    this as? JsonArray ?: error("Expected JSON array, got ${this::class.simpleName}")

internal fun JsonElement.asJsonPrimitive(): JsonPrimitive =
    this as? JsonPrimitive ?: error("Expected JSON primitive, got ${this::class.simpleName}")
