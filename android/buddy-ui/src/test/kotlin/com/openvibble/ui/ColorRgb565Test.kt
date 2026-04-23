// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class ColorRgb565Test {

    @Test
    fun white_roundtrips_to_full_white() {
        val c = colorFromRgb565(0xFFFF)
        assertEquals(1.0f, c.red, 0f)
        assertEquals(1.0f, c.green, 0f)
        assertEquals(1.0f, c.blue, 0f)
    }

    @Test
    fun black_roundtrips_to_zero() {
        val c = colorFromRgb565(0x0000)
        assertEquals(0.0f, c.red, 0f)
        assertEquals(0.0f, c.green, 0f)
        assertEquals(0.0f, c.blue, 0f)
    }

    @Test
    fun firmware_yellow_is_near_pure_yellow() {
        val c = colorFromRgb565(0xFFE0) // BUDDY_YEL: r=31, g=63, b=0
        assertEquals(1.0f, c.red, 0f)
        assertEquals(1.0f, c.green, 0f)
        assertEquals(0.0f, c.blue, 0f)
    }

    @Test
    fun firmware_cyan_is_near_pure_cyan() {
        val c = colorFromRgb565(0x07FF) // CYAN: r=0, g=63, b=31
        assertEquals(0.0f, c.red, 0f)
        assertEquals(1.0f, c.green, 0f)
        assertEquals(1.0f, c.blue, 0f)
    }

    @Test
    fun firmware_heart_is_red_biased() {
        val c = colorFromRgb565(0xF810) // HEART: r=31, g=0, b=16
        assertEquals(1.0f, c.red, 0f)
        assertEquals(0.0f, c.green, 0f)
        assertEquals((16 shl 3 or (16 shr 2)) / 255f, c.blue, 1e-6f)
    }

    @Test
    fun ignores_bits_above_16() {
        val base = colorFromRgb565(0xFFE0)
        val withNoise = colorFromRgb565(0x1FFE0)
        assertEquals(base.red, withNoise.red, 0f)
        assertEquals(base.green, withNoise.green, 0f)
        assertEquals(base.blue, withNoise.blue, 0f)
    }
}
