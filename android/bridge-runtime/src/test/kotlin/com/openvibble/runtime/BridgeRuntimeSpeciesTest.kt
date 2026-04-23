// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.protocol.BridgeAck
import com.openvibble.storage.CharacterTransferStore
import java.io.File
import java.nio.file.Files
import java.util.UUID
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Mirrors iOS BridgeRuntimeSpeciesTests.swift. Valid idx [0, 18) saves to the
 * PersonaSelectionStore + ACK ok; sentinel 0xFF restores GIF or keeps the
 * current builtin; out-of-range idx yields ACK false with "invalid idx".
 */
class BridgeRuntimeSpeciesTest {

    private lateinit var tempRoot: File

    @Before fun setUp() {
        tempRoot = Files.createTempDirectory("bridge-species-${UUID.randomUUID()}").toFile()
    }

    @After fun tearDown() {
        tempRoot.deleteRecursively()
    }

    private fun makeRuntime(selection: InMemoryPersonaSelectionStore): BridgeRuntime =
        BridgeRuntime(
            transferStore = CharacterTransferStore(rootDirectory = tempRoot),
            personaSelection = selection,
        )

    private fun decodeAck(line: String): BridgeAck =
        Json.decodeFromString(BridgeAck.serializer(), line)

    @Test fun validIdxSavesAsciiSpeciesAndAcksOk() {
        val selection = InMemoryPersonaSelectionStore(PersonaSpeciesId.AsciiCat)
        val runtime = makeRuntime(selection)

        var observed: Int? = null
        runtime.onSpeciesChanged = { observed = it }

        val lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":7}")
        assertEquals(1, lines.size)

        val ack = decodeAck(lines[0])
        assertEquals("species", ack.ack)
        assertTrue(ack.ok)
        assertNull(ack.error)
        assertEquals(7, observed)

        val loaded = selection.load()
        assertTrue(loaded is PersonaSpeciesId.AsciiSpecies)
        assertEquals(7, (loaded as PersonaSpeciesId.AsciiSpecies).idx)
    }

    @Test fun sentinelRestoresGifKeepsBuiltinWhenAlreadyGif() {
        val selection = InMemoryPersonaSelectionStore(PersonaSpeciesId.Builtin("bufo"))
        val runtime = makeRuntime(selection)

        var observed: Int? = null
        runtime.onSpeciesChanged = { observed = it }

        val lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":255}")
        val ack = decodeAck(lines[0])
        assertTrue(ack.ok)
        assertEquals(0xFF, observed)

        val loaded = selection.load()
        assertTrue(loaded is PersonaSpeciesId.Builtin)
        assertEquals("bufo", (loaded as PersonaSpeciesId.Builtin).name)
    }

    @Test fun sentinelFallsBackToAsciiCatWhenNoGifSelected() {
        val selection = InMemoryPersonaSelectionStore(PersonaSpeciesId.AsciiSpecies(3))
        val runtime = makeRuntime(selection)

        val lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":255}")
        val ack = decodeAck(lines[0])
        assertTrue(ack.ok)
        assertEquals(PersonaSpeciesId.AsciiCat, selection.load())
    }

    @Test fun negativeIdxAcksFalse() {
        val selection = InMemoryPersonaSelectionStore()
        val runtime = makeRuntime(selection)

        val lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":-1}")
        val ack = decodeAck(lines[0])
        assertFalse(ack.ok)
        assertEquals("species", ack.ack)
        assertEquals("invalid idx", ack.error)
    }

    @Test fun outOfRangeIdxAcksFalse() {
        val selection = InMemoryPersonaSelectionStore()
        val runtime = makeRuntime(selection)

        val lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":100}")
        val ack = decodeAck(lines[0])
        assertFalse(ack.ok)
        assertEquals("invalid idx", ack.error)
    }
}
