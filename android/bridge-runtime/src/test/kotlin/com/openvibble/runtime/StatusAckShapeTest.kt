// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

import com.openvibble.storage.CharacterTransferStore
import java.io.File
import java.nio.file.Files
import java.util.UUID
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Mirrors iOS StatusAckShapeTests.swift. Pins the `status` ACK shape to the
 * firmware/h5 REFERENCE.md contract: `name, owner, sec, bat{pct,mV,mA,usb},
 * sys{up,heap,fsFree,fsTotal}, stats{appr,deny,vel,nap,lvl}`. `xfer` is an
 * iOS-compat extension tolerated by desktop.
 */
class StatusAckShapeTest {

    private lateinit var tempRoot: File

    @Before fun setUp() {
        tempRoot = Files.createTempDirectory("bridge-status-${UUID.randomUUID()}").toFile()
    }

    @After fun tearDown() {
        tempRoot.deleteRecursively()
    }

    private fun makeRuntime(): BridgeRuntime =
        BridgeRuntime(
            transferStore = CharacterTransferStore(rootDirectory = tempRoot),
            personaSelection = InMemoryPersonaSelectionStore(),
        )

    private fun JsonObject.child(key: String): JsonObject {
        val element: JsonElement = this[key] ?: error("missing $key")
        return element.jsonObject
    }

    @Test fun statusAckExposesFirmwareShape() {
        val runtime = makeRuntime()
        val lines = runtime.ingestLine("{\"cmd\":\"status\"}")
        assertEquals(1, lines.size)

        val root = Json.parseToJsonElement(lines[0]).jsonObject
        assertEquals("status", root["ack"]?.jsonPrimitive?.content)
        assertEquals(true, root["ok"]?.jsonPrimitive?.booleanOrNull)

        val data = root.child("data")
        assertNotNull(data["name"])
        assertNotNull(data["owner"])
        assertEquals(false, data["sec"]?.jsonPrimitive?.booleanOrNull)

        val bat = data.child("bat")
        assertNotNull(bat["pct"])
        assertNotNull(bat["mV"])
        assertNotNull(bat["mA"])
        assertNotNull(bat["usb"]?.jsonPrimitive?.booleanOrNull)

        val sys = data.child("sys")
        assertNotNull(sys["up"])
        assertNotNull(sys["heap"])
        assertNotNull("fsFree must be present to match REFERENCE.md", sys["fsFree"])
        assertNotNull("fsTotal must be present to match REFERENCE.md", sys["fsTotal"])

        val stats = data.child("stats")
        for (key in listOf("appr", "deny", "vel", "nap", "lvl")) {
            assertNotNull("stats.$key missing", stats[key])
        }

        val xfer = data.child("xfer")
        assertNotNull(xfer["active"]?.jsonPrimitive?.booleanOrNull)
        assertNotNull(xfer["total"])
        assertNotNull(xfer["written"])
    }

    @Test fun sysUpIsSessionScopedAndNonNegative() {
        val runtime = makeRuntime()
        val lines = runtime.ingestLine("{\"cmd\":\"status\"}")
        val data = Json.parseToJsonElement(lines[0]).jsonObject.child("data")
        val sys = data.child("sys")
        val up = sys["up"]?.jsonPrimitive?.longOrNull ?: error("sys.up not a number")

        assertTrue("up >= 0", up >= 0)
        assertTrue("up=$up looks like device boot uptime, not session uptime", up < 600)
    }
}
