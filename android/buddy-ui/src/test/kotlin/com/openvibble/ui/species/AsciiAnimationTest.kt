// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class AsciiAnimationTest {

    @Test
    fun frame_at_uses_ticks_per_beat() {
        val poses = listOf(
            AsciiFrame(listOf("A")),
            AsciiFrame(listOf("B")),
            AsciiFrame(listOf("C")),
        )
        val anim = AsciiAnimation(poses = poses, sequence = listOf(0, 1, 2), ticksPerBeat = 5)
        assertSame(poses[0], anim.frameAt(0))
        assertSame(poses[0], anim.frameAt(4))
        assertSame(poses[1], anim.frameAt(5))
        assertSame(poses[1], anim.frameAt(9))
        assertSame(poses[2], anim.frameAt(10))
    }

    @Test
    fun frame_at_wraps_sequence() {
        val poses = listOf(AsciiFrame(listOf("A")), AsciiFrame(listOf("B")))
        val anim = AsciiAnimation(poses = poses, sequence = listOf(0, 1), ticksPerBeat = 1)
        assertSame(poses[0], anim.frameAt(0))
        assertSame(poses[1], anim.frameAt(1))
        assertSame(poses[0], anim.frameAt(2))
        assertSame(poses[1], anim.frameAt(3))
    }

    @Test
    fun frame_at_handles_negative_tick() {
        val poses = listOf(AsciiFrame(listOf("A")), AsciiFrame(listOf("B")))
        val anim = AsciiAnimation(poses = poses, sequence = listOf(0, 1), ticksPerBeat = 1)
        // -1 / 1 = -1, (-1).mod(2) == 1
        assertSame(poses[1], anim.frameAt(-1))
        assertSame(poses[0], anim.frameAt(-2))
    }

    @Test
    fun repeated_pose_in_sequence_holds_for_consecutive_beats() {
        val poses = listOf(AsciiFrame(listOf("X")), AsciiFrame(listOf("Y")))
        val anim = AsciiAnimation(poses = poses, sequence = listOf(0, 0, 1), ticksPerBeat = 2)
        assertSame(poses[0], anim.frameAt(0))
        assertSame(poses[0], anim.frameAt(3)) // beat index 1 → still pose 0
        assertSame(poses[1], anim.frameAt(4)) // beat index 2 → pose 1
    }

    @Test
    fun frame_lines_preserved() {
        val frame = AsciiFrame(listOf("   /\\_/\\   ", "  ( o o )  "))
        assertEquals(2, frame.lines.size)
        assertEquals("   /\\_/\\   ", frame.lines[0])
    }
}
