// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.protocol

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class NDJSONCodecTest {

    @Test
    fun framerHandlesStickyAndSplitPackets() {
        val framer = NDJSONLineFramer()
        val part1 = "{\"a\":1}\n{\"b\":2".toByteArray()
        val lines1 = framer.ingest(part1)
        assertEquals(listOf("{\"a\":1}"), lines1)

        val part2 = "}\n".toByteArray()
        val lines2 = framer.ingest(part2)
        assertEquals(listOf("{\"b\":2}"), lines2)
    }

    @Test
    fun framerIgnoresBlankLines() {
        val framer = NDJSONLineFramer()
        val lines = framer.ingest("\n\n{\"ok\":true}\n\n".toByteArray())
        assertEquals(listOf("{\"ok\":true}"), lines)
    }

    @Test
    fun framerResetClearsBuffer() {
        val framer = NDJSONLineFramer()
        framer.ingest("{\"partial\":".toByteArray())
        framer.reset()
        val lines = framer.ingest("{\"ok\":true}\n".toByteArray())
        assertEquals(listOf("{\"ok\":true}"), lines)
    }

    @Test
    fun decodeHeartbeat() {
        val line = """
            {"total":3,"running":1,"waiting":1,"msg":"approve: Bash","entries":["10:42 git push"],"tokens":100,"tokens_today":20,"prompt":{"id":"req_1","tool":"Bash","hint":"rm -rf /tmp"}}
        """.trimIndent()

        val msg = NDJSONCodec.decodeInboundLine(line)
        assertTrue("expected heartbeat, got $msg", msg is BridgeInboundMessage.Heartbeat)
        val snap = (msg as BridgeInboundMessage.Heartbeat).snapshot
        assertEquals(3, snap.total)
        assertEquals(20, snap.tokensToday)
        assertEquals("req_1", snap.prompt?.id)
    }

    @Test
    fun decodeStatusCommand() {
        val msg = NDJSONCodec.decodeInboundLine("{\"cmd\":\"status\"}")
        assertEquals(BridgeInboundMessage.Command(BridgeCommand.Status), msg)
    }

    @Test
    fun decodePermissionCommandWithUnknownDecisionFallsBackToDeny() {
        val msg = NDJSONCodec.decodeInboundLine(
            "{\"cmd\":\"permission\",\"id\":\"req_abc\",\"decision\":\"what\"}"
        )
        val cmd = (msg as BridgeInboundMessage.Command).command
        assertEquals(BridgeCommand.Permission("req_abc", PermissionDecision.DENY), cmd)
    }

    @Test
    fun decodeSpeciesAcceptsStringIndex() {
        val msg = NDJSONCodec.decodeInboundLine("{\"cmd\":\"species\",\"idx\":\"5\"}")
        val cmd = (msg as BridgeInboundMessage.Command).command
        assertEquals(BridgeCommand.Species(5), cmd)
    }

    @Test
    fun decodeTimeSync() {
        val msg = NDJSONCodec.decodeInboundLine("{\"time\":[1717000000,28800]}")
        val sync = (msg as BridgeInboundMessage.Time).sync
        assertEquals(1717000000L, sync.epochSeconds)
        assertEquals(28800, sync.timezoneOffsetSeconds)
    }

    @Test
    fun decodeTurnEvent() {
        val msg = NDJSONCodec.decodeInboundLine(
            "{\"evt\":\"turn\",\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"hi\"}]}"
        )
        val turn = (msg as BridgeInboundMessage.Turn).event
        assertEquals("assistant", turn.role)
        assertEquals(1, turn.content.size)
    }

    @Test
    fun decodeUnknownEnvelopeThrows() {
        try {
            NDJSONCodec.decodeInboundLine("{\"unknown\":true}")
            fail("expected BridgeProtocolException")
        } catch (_: BridgeProtocolException) {
            // ok
        }
    }

    @Test
    fun encodePermissionCommandAsNDJSON() {
        val line = NDJSONCodec.encodeLine(PermissionCommand(id = "req_abc", decision = PermissionDecision.ONCE))
        assertTrue(line.endsWith("\n"))
        assertTrue(line.contains("\"cmd\":\"permission\""))
        assertTrue(line.contains("\"decision\":\"once\""))
        assertTrue(line.contains("\"id\":\"req_abc\""))
    }

    @Test
    fun encodeTimeSyncRoundTrip() {
        val line = NDJSONCodec.encodeLine(TimeSync(epochSeconds = 1700000000L, timezoneOffsetSeconds = -3600))
        assertTrue(line.trim().startsWith("{\"time\":["))
        val msg = NDJSONCodec.decodeInboundLine(line.trim())
        val sync = (msg as BridgeInboundMessage.Time).sync
        assertEquals(1700000000L, sync.epochSeconds)
        assertEquals(-3600, sync.timezoneOffsetSeconds)
    }
}
