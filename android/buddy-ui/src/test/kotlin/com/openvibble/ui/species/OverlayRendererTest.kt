// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class OverlayRendererTest {

    @Test
    fun fixed_path_returns_same_point_regardless_of_tick() {
        val path = OverlayPath.Fixed(col = 3.5, row = 1.25)
        val a = OverlayRenderer.position(path, tick = 0)
        val b = OverlayRenderer.position(path, tick = 1234)
        assertEquals(3.5, a.col, 1e-9)
        assertEquals(1.25, a.row, 1e-9)
        assertEquals(a.col, b.col, 1e-9)
        assertEquals(a.row, b.row, 1e-9)
    }

    @Test
    fun linear_path_wraps_over_span() {
        val path = OverlayPath.Linear(
            originCol = 0.0,
            originRow = 10.0,
            dxPerTick = 1.0,
            dyPerTick = -0.5,
            phase = 0.0,
            span = 4.0,
        )
        val p0 = OverlayRenderer.position(path, tick = 0)
        val p3 = OverlayRenderer.position(path, tick = 3)
        val p4 = OverlayRenderer.position(path, tick = 4) // wraps
        assertEquals(0.0, p0.col, 1e-9)
        assertEquals(10.0, p0.row, 1e-9)
        assertEquals(3.0, p3.col, 1e-9)
        assertEquals(8.5, p3.row, 1e-9)
        assertEquals(0.0, p4.col, 1e-9)
        assertEquals(10.0, p4.row, 1e-9)
    }

    @Test
    fun orbit_path_matches_cos_sin() {
        val path = OverlayPath.Orbit(radius = 5.0, speed = 0.5, phase = 0.0)
        val t = 3
        val angle = t.toDouble() * 0.5
        val expectedCol = cos(angle) * 5.0
        val expectedRow = sin(angle) * 5.0
        val p = OverlayRenderer.position(path, tick = t)
        assertEquals(expectedCol, p.col, 1e-9)
        assertEquals(expectedRow, p.row, 1e-9)
    }

    @Test
    fun bobble_path_oscillates_around_base() {
        val path = OverlayPath.Bobble(col = 2.0, row = 4.0, amp = 1.0, speed = 1.0)
        val p = OverlayRenderer.position(path, tick = 7)
        assertEquals(2.0, p.col, 1e-9)
        assertEquals(4.0 + sin(7.0), p.row, 1e-9)
    }

    @Test
    fun baked_path_wraps_and_handles_empty() {
        val points = listOf(
            BakedPoint(0.0, 0.0),
            BakedPoint(1.0, 2.0),
            BakedPoint(3.0, 4.0),
        )
        val path = OverlayPath.Baked(points)
        val p0 = OverlayRenderer.position(path, tick = 0)
        val p2 = OverlayRenderer.position(path, tick = 2)
        val p3 = OverlayRenderer.position(path, tick = 3) // wraps
        val pNeg = OverlayRenderer.position(path, tick = -1) // negative wraps
        assertEquals(0.0, p0.col, 1e-9)
        assertEquals(3.0, p2.col, 1e-9)
        assertEquals(0.0, p3.col, 1e-9)
        assertEquals(3.0, pNeg.col, 1e-9)

        val empty = OverlayPath.Baked(emptyList())
        val pe = OverlayRenderer.position(empty, tick = 5)
        assertEquals(0.0, pe.col, 1e-9)
        assertEquals(0.0, pe.row, 1e-9)
    }

    @Test
    fun visibility_always_is_always_true() {
        assertTrue(OverlayRenderer.isVisible(OverlayVisibility.Always, tick = 0))
        assertTrue(OverlayRenderer.isVisible(OverlayVisibility.Always, tick = 999_999))
    }

    @Test
    fun visibility_tick_mod_only_active_in_selected_slots() {
        val vis = OverlayVisibility.TickMod(period = 4, activeTicks = listOf(2, 3))
        assertFalse(OverlayRenderer.isVisible(vis, tick = 0))
        assertFalse(OverlayRenderer.isVisible(vis, tick = 1))
        assertTrue(OverlayRenderer.isVisible(vis, tick = 2))
        assertTrue(OverlayRenderer.isVisible(vis, tick = 3))
        assertFalse(OverlayRenderer.isVisible(vis, tick = 4))
        assertTrue(OverlayRenderer.isVisible(vis, tick = 6))
    }

    @Test
    fun visibility_tick_mod_handles_negative_ticks() {
        val vis = OverlayVisibility.TickMod(period = 3, activeTicks = listOf(0))
        assertTrue(OverlayRenderer.isVisible(vis, tick = -3))
        assertTrue(OverlayRenderer.isVisible(vis, tick = 0))
        assertFalse(OverlayRenderer.isVisible(vis, tick = -1))
    }

    @Test
    fun linear_path_applies_phase_before_wrap() {
        val path = OverlayPath.Linear(
            originCol = 100.0,
            originRow = 0.0,
            dxPerTick = 1.0,
            dyPerTick = 0.0,
            phase = 1.0,
            span = 4.0,
        )
        assertEquals(101.0, OverlayRenderer.position(path, tick = 0).col, 1e-9)
        assertEquals(102.0, OverlayRenderer.position(path, tick = 1).col, 1e-9)
        assertEquals(100.0, OverlayRenderer.position(path, tick = 3).col, 1e-9) // (3+1)%4=0
    }
}
