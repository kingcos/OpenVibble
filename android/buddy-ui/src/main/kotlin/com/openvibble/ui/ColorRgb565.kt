// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui

import androidx.compose.ui.graphics.Color

/**
 * Decode an RGB565 (5-6-5 packed) value the same way the
 * `claude-desktop-buddy` firmware drives its TFT. Expands the 5/6-bit
 * channels to 8-bit using the standard `(x << 3) | (x >> 2)` scheme so the
 * Android UI renders identically to iOS.
 */
fun colorFromRgb565(rgb565: Int): Color {
    val raw = rgb565 and 0xFFFF
    val r5 = (raw shr 11) and 0x1F
    val g6 = (raw shr 5) and 0x3F
    val b5 = raw and 0x1F
    val r8 = ((r5 shl 3) or (r5 shr 2)) and 0xFF
    val g8 = ((g6 shl 2) or (g6 shr 4)) and 0xFF
    val b8 = ((b5 shl 3) or (b5 shr 2)) and 0xFF
    return Color(red = r8 / 255f, green = g8 / 255f, blue = b8 / 255f)
}
