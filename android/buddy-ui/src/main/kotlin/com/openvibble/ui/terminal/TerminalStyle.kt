// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

/**
 * Android parity with iOS `TerminalStyle` (OpenVibbleApp/UI/TerminalStyle.swift).
 *
 * Palette is lifted verbatim from h5-demo.html so the Android UI matches the
 * H5 dev-board replica of the M5 handheld. Colors are declared as Compose
 * [Color]s so they can be consumed directly by any composable.
 */
object TerminalPalette {
    // LCD inks
    val ink = Color(0xFFCDE8CE)
    val inkDim = Color(0xFF6F8571)

    // LCD backgrounds
    val lcdBg = Color(0xFF0F1010)
    val lcdBgHi = Color(0xFF1A1B1B)
    val lcdPanel = Color(0xFF212222)
    val lcdDivider = Color(0xFF2E2F2E)

    // Warm accents
    val accent = Color(0xFFEA5A2A)
    val accentSoft = Color(0xFFFFB35D)
    val bad = Color(0xFFD03832)
    val good = Color(0xFF168E57)

    // Mood heart tiers
    val moodHot = Color(0xFFF15A50)
    val moodWarm = Color(0xFFF0A34F)
    val moodDim = Color(0xFF8F988E)

    // Energy bar tiers
    val enHigh = Color(0xFF6BD8F3)
    val enMid = Color(0xFFE8E56B)
    val enLow = Color(0xFFEF6A50)

    // Salmon LV badge
    val levelBg = Color(0xFFEAC6B7)
    val levelInk = Color(0xFF201F1D)

    val shellBottom = Color(0xFFDB4215)

    val panelFill: Color = lcdBgHi.copy(alpha = 0.72f)

    val backgroundBrush: Brush = Brush.verticalGradient(
        colors = listOf(lcdBg, Color.Black),
    )
}

/**
 * Centralised font factories so screens never hard-code `FontFamily.Monospace`
 * directly — makes it easy to swap to a bundled mono font later.
 */
object TerminalFonts {
    val mono: FontFamily = FontFamily.Monospace

    // Android has no Compose equivalent of iOS `design: .default + width: .condensed`,
    // so display copy uses extra-bold sans and relies on sizing for impact.
    val display: FontFamily = FontFamily.Default

    fun mono(weight: FontWeight = FontWeight.Normal): Pair<FontFamily, FontWeight> =
        mono to weight

    fun display(weight: FontWeight = FontWeight.ExtraBold): Pair<FontFamily, FontWeight> =
        display to weight

    fun sp(size: Int): TextUnit = size.sp
}
