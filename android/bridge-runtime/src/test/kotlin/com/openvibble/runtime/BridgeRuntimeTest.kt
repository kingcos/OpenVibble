// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

import com.openvibble.persona.PersonaSelection
import com.openvibble.persona.PersonaSelectionStore
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.protocol.BridgeAck
import com.openvibble.protocol.PermissionDecision
import com.openvibble.storage.CharacterTransferStore
import java.io.File
import java.nio.file.Files
import java.util.UUID
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Mirrors iOS BridgeRuntimeTests.swift (status ack, permission round-trip,
 * prompt latching, full NDJSON replay with transfer flow) plus
 * HeartbeatCompletedTests (one-shot `completed: true` callback).
 */
class BridgeRuntimeTest {

    private lateinit var tempRoot: File
    private lateinit var selectionStore: InMemoryPersonaSelectionStore

    @Before fun setUp() {
        tempRoot = Files.createTempDirectory("bridge-runtime-${UUID.randomUUID()}").toFile()
        selectionStore = InMemoryPersonaSelectionStore()
    }

    @After fun tearDown() {
        tempRoot.deleteRecursively()
    }

    private fun makeRuntime(): BridgeRuntime {
        val store = CharacterTransferStore(rootDirectory = tempRoot)
        return BridgeRuntime(
            transferStore = store,
            personaSelection = selectionStore,
        )
    }

    @Test fun emitsStatusAck() {
        val runtime = makeRuntime()
        val lines = runtime.ingestLine("{\"cmd\":\"status\"}")
        assertEquals(1, lines.size)

        val ack = Json.decodeFromString(BridgeAck.serializer(), lines[0])
        assertEquals("status", ack.ack)
        assertTrue(ack.ok)
    }

    @Test fun permissionRoundTripAfterHeartbeatPrompt() {
        val runtime = makeRuntime()
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\"," +
                "\"entries\":[\"line\"]," +
                "\"prompt\":{\"id\":\"req_1\",\"tool\":\"Bash\",\"hint\":\"ls\"}}",
        )

        val line = runtime.respondPermission(PermissionDecision.ONCE)
        assertNotNull(line)
        assertTrue(line!!.contains("\"cmd\":\"permission\""))
        assertTrue(line.contains("\"id\":\"req_1\""))
    }

    /**
     * After responding to a prompt the runtime must clear its local prompt
     * StateFlow immediately so UI doesn't keep offering Approve/Deny while the
     * BLE round-trip completes. Protects the "no visible reaction" fix.
     */
    @Test fun respondPermissionClearsPendingPromptOptimistically() {
        val runtime = makeRuntime()
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
                "\"prompt\":{\"id\":\"req_42\",\"tool\":\"Bash\",\"hint\":\"rm -rf\"}}",
        )
        assertEquals("req_42", runtime.prompt.value?.id)

        runtime.respondPermission(PermissionDecision.DENY)
        assertNull(runtime.prompt.value)

        // A second respond with no live prompt returns null.
        assertNull(runtime.respondPermission(PermissionDecision.ONCE))
    }

    /**
     * A heartbeat echoing the just-answered prompt id must not re-seat it —
     * otherwise the UI flickers Approve/Deny back on between send and desktop
     * confirmation.
     */
    @Test fun heartbeatWithAnsweredPromptIdIsIgnored() {
        val runtime = makeRuntime()
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
                "\"prompt\":{\"id\":\"req_77\",\"tool\":\"Write\",\"hint\":\"\"}}",
        )
        runtime.respondPermission(PermissionDecision.ONCE)
        assertNull(runtime.prompt.value)

        // Stale heartbeat still carrying the same prompt id: must stay cleared.
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
                "\"prompt\":{\"id\":\"req_77\",\"tool\":\"Write\",\"hint\":\"\"}}",
        )
        assertNull(runtime.prompt.value)

        // A NEW prompt id is a genuinely new request — must surface it.
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
                "\"prompt\":{\"id\":\"req_78\",\"tool\":\"Bash\",\"hint\":\"\"}}",
        )
        assertEquals("req_78", runtime.prompt.value?.id)

        // After responding to req_78 and desktop confirms (no prompt), the
        // answered-id latch must reset so a future heartbeat reusing req_78
        // is accepted again.
        runtime.respondPermission(PermissionDecision.DENY)
        runtime.ingestLine("{\"total\":1,\"running\":0,\"waiting\":0,\"msg\":\"ok\",\"entries\":[]}")
        assertNull(runtime.prompt.value)
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
                "\"prompt\":{\"id\":\"req_78\",\"tool\":\"Bash\",\"hint\":\"\"}}",
        )
        assertEquals("req_78", runtime.prompt.value?.id)
    }

    @Test fun protocolReplayWithTransferFlow() {
        val runtime = makeRuntime()

        runtime.ingestLine("{\"time\":[1775731234,-25200]}")
        runtime.ingestLine(
            "{\"total\":2,\"running\":1,\"waiting\":0,\"msg\":\"working\"," +
                "\"entries\":[\"10:42 git push\"],\"tokens\":100,\"tokens_today\":12}",
        )

        val beginAck = runtime.ingestLine("{\"cmd\":\"char_begin\",\"name\":\"bufo\",\"total\":5}")
        runtime.ingestLine("{\"cmd\":\"file\",\"path\":\"manifest.json\",\"size\":5}")
        runtime.ingestLine("{\"cmd\":\"chunk\",\"d\":\"aGVsbG8=\"}")
        val fileEndAck = runtime.ingestLine("{\"cmd\":\"file_end\"}")
        val charEndAck = runtime.ingestLine("{\"cmd\":\"char_end\"}")

        assertEquals(1, beginAck.size)
        assertEquals(1, fileEndAck.size)
        assertEquals(1, charEndAck.size)

        val begin = Json.decodeFromString(BridgeAck.serializer(), beginAck[0])
        val fileEnd = Json.decodeFromString(BridgeAck.serializer(), fileEndAck[0])
        val charEnd = Json.decodeFromString(BridgeAck.serializer(), charEndAck[0])
        assertTrue(begin.ok)
        assertTrue(fileEnd.ok)
        assertTrue(charEnd.ok)

        val snapshot = runtime.snapshot.value
        assertEquals(2, snapshot.total)
        assertEquals("working", snapshot.msg)
        assertEquals(100, snapshot.tokens)
        assertEquals(12, snapshot.tokensToday)
    }

    @Test fun completedTrueFiresCallback() {
        val runtime = makeRuntime()
        var callCount = 0
        runtime.onTaskCompleted = { callCount += 1 }

        runtime.ingestLine(
            "{\"total\":2,\"running\":0,\"waiting\":0,\"msg\":\"done\",\"entries\":[],\"completed\":true}",
        )
        assertEquals(1, callCount)
    }

    @Test fun completedFalseDoesNotFireCallback() {
        val runtime = makeRuntime()
        var callCount = 0
        runtime.onTaskCompleted = { callCount += 1 }

        runtime.ingestLine(
            "{\"total\":2,\"running\":1,\"waiting\":0,\"msg\":\"working\",\"entries\":[],\"completed\":false}",
        )
        assertEquals(0, callCount)
    }

    @Test fun missingCompletedFieldDoesNotFireCallback() {
        val runtime = makeRuntime()
        var callCount = 0
        runtime.onTaskCompleted = { callCount += 1 }

        runtime.ingestLine(
            "{\"total\":1,\"running\":1,\"waiting\":0,\"msg\":\"still working\",\"entries\":[]}",
        )
        assertEquals(0, callCount)
    }

    @Test fun nameCommandRequiresName() {
        val runtime = makeRuntime()
        val empty = runtime.ingestLine("{\"cmd\":\"name\",\"name\":\"\"}")
        val emptyAck = Json.decodeFromString(BridgeAck.serializer(), empty[0])
        assertFalse(emptyAck.ok)
        assertEquals("name required", emptyAck.error)

        val ok = runtime.ingestLine("{\"cmd\":\"name\",\"name\":\"Pet\"}")
        val okAck = Json.decodeFromString(BridgeAck.serializer(), ok[0])
        assertTrue(okAck.ok)
        assertEquals("Pet", runtime.snapshot.value.deviceName)
    }

    @Test fun ownerCommandAcceptsAnyStringAndUpdatesSnapshot() {
        val runtime = makeRuntime()
        val out = runtime.ingestLine("{\"cmd\":\"owner\",\"name\":\"Claude\"}")
        val ack = Json.decodeFromString(BridgeAck.serializer(), out[0])
        assertTrue(ack.ok)
        assertEquals("Claude", runtime.snapshot.value.ownerName)
    }

    @Test fun unpairResetsPromptAndTransferState() {
        val runtime = makeRuntime()
        runtime.ingestLine(
            "{\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
                "\"prompt\":{\"id\":\"req_99\",\"tool\":\"Bash\",\"hint\":\"\"}}",
        )
        assertNotNull(runtime.prompt.value)

        val out = runtime.ingestLine("{\"cmd\":\"unpair\"}")
        val ack = Json.decodeFromString(BridgeAck.serializer(), out[0])
        assertTrue(ack.ok)
        assertNull(runtime.prompt.value)
        assertFalse(runtime.transferProgress.value.isActive)
    }

    @Test fun unknownCommandAcksFalse() {
        val runtime = makeRuntime()
        val out = runtime.ingestLine("{\"cmd\":\"banana\",\"flavor\":\"strawberry\"}")
        val ack = Json.decodeFromString(BridgeAck.serializer(), out[0])
        assertFalse(ack.ok)
        assertEquals("banana", ack.ack)
        assertEquals("unsupported command", ack.error)
    }

    @Test fun malformedJsonProducesNoOutputAndDoesNotCrash() {
        val runtime = makeRuntime()
        val out = runtime.ingestLine("not json at all")
        assertTrue(out.isEmpty())
    }

    @Test fun turnEventUpdatesLastTurnPreview() {
        val runtime = makeRuntime()
        runtime.ingestLine(
            "{\"evt\":\"turn\",\"role\":\"assistant\",\"content\":[\"hi there\"]}",
        )
        val snap = runtime.snapshot.value
        assertEquals("assistant", snap.lastTurnRole)
        assertEquals("hi there", snap.lastTurnPreview)
    }
}

/** In-memory selection store so tests stay pure-JVM (no SharedPreferences). */
class InMemoryPersonaSelectionStore(
    initial: PersonaSpeciesId = PersonaSelection.defaultSpecies,
) : PersonaSelectionStore {
    private var value: PersonaSpeciesId = initial
    override fun load(): PersonaSpeciesId = value
    override fun save(selection: PersonaSpeciesId) {
        value = selection
    }
}
