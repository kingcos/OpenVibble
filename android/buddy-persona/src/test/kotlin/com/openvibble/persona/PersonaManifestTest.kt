// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PersonaManifestTest {

    @Test
    fun parseSingleFrameString() {
        val m = PersonaManifest.fromJson(
            """{"name":"bufo","mode":"gif","states":{"idle":"idle.gif"}}"""
        )!!
        assertEquals("bufo", m.name)
        assertEquals(PersonaMode.GIF, m.mode)
        assertEquals(listOf("idle.gif"), m.framesFor("idle")?.filenames)
    }

    @Test
    fun parseVariantsArray() {
        val m = PersonaManifest.fromJson(
            """{"name":"bufo","states":{"busy":["b1.gif","b2.gif"]}}"""
        )!!
        assertEquals(listOf("b1.gif", "b2.gif"), m.framesFor("busy")?.filenames)
    }

    @Test
    fun parseTextStateObject() {
        val m = PersonaManifest.fromJson(
            """{"name":"ascii","mode":"text","states":{"idle":{"frames":["a","b"],"delay_ms":300}}}"""
        )!!
        val text = m.framesFor("idle")
        assertTrue("expected text state", text is StateFrames.Text)
        val t = text as StateFrames.Text
        assertEquals(listOf("a", "b"), t.frames)
        assertEquals(300, t.delayMs)
    }

    @Test
    fun parseMissingStatesReturnsEmpty() {
        val m = PersonaManifest.fromJson("""{"name":"x"}""")!!
        assertEquals("x", m.name)
        assertNull(m.framesFor("idle"))
    }

    @Test
    fun parseInvalidStateValueDegradesGracefully() {
        // iOS: when the states map itself can't be decoded (e.g. value is Int),
        // the catch block makes states empty but the manifest still loads.
        val m = PersonaManifest.fromJson("""{"name":"bad","states":{"idle":42}}""")
        assertNotNull(m)
        assertNull(m!!.framesFor("idle"))
    }
}
