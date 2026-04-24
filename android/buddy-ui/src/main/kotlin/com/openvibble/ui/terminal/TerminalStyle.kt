// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

enum class TerminalThemeMode {
    EInk,
    ClassicLcd,
}

private data class TerminalColors(
    val ink: Color,
    val inkDim: Color,
    val lcdBg: Color,
    val lcdBgHi: Color,
    val lcdPanel: Color,
    val lcdDivider: Color,
    val accent: Color,
    val accentSoft: Color,
    val bad: Color,
    val good: Color,
    val moodHot: Color,
    val moodWarm: Color,
    val moodDim: Color,
    val enHigh: Color,
    val enMid: Color,
    val enLow: Color,
    val levelBg: Color,
    val levelInk: Color,
    val shellBottom: Color,
    val backgroundEnd: Color,
    val panelAlpha: Float,
)

/**
 * Central terminal palette. EInk is the Android default so reflective screens
 * get high contrast and minimal hue, while ClassicLcd preserves the original
 * dev-board look for phones and tablets.
 */
object TerminalPalette {
    var mode: TerminalThemeMode by mutableStateOf(TerminalThemeMode.EInk)

    private val active: TerminalColors
        get() = when (mode) {
            TerminalThemeMode.EInk -> eink
            TerminalThemeMode.ClassicLcd -> classicLcd
        }

    val ink: Color get() = active.ink
    val inkDim: Color get() = active.inkDim
    val lcdBg: Color get() = active.lcdBg
    val lcdBgHi: Color get() = active.lcdBgHi
    val lcdPanel: Color get() = active.lcdPanel
    val lcdDivider: Color get() = active.lcdDivider
    val accent: Color get() = active.accent
    val accentSoft: Color get() = active.accentSoft
    val bad: Color get() = active.bad
    val good: Color get() = active.good
    val moodHot: Color get() = active.moodHot
    val moodWarm: Color get() = active.moodWarm
    val moodDim: Color get() = active.moodDim
    val enHigh: Color get() = active.enHigh
    val enMid: Color get() = active.enMid
    val enLow: Color get() = active.enLow
    val levelBg: Color get() = active.levelBg
    val levelInk: Color get() = active.levelInk
    val shellBottom: Color get() = active.shellBottom
    val panelFill: Color get() = lcdBgHi.copy(alpha = active.panelAlpha)
    val backgroundBrush: Brush get() = Brush.verticalGradient(
        colors = listOf(lcdBg, active.backgroundEnd),
    )

    private val eink = TerminalColors(
        ink = Color(0xFF111111),
        inkDim = Color(0xFF666666),
        lcdBg = Color(0xFFF4F2EA),
        lcdBgHi = Color(0xFFE9E6DD),
        lcdPanel = Color(0xFFFFFFFF),
        lcdDivider = Color(0xFFCFCAC0),
        accent = Color(0xFF111111),
        accentSoft = Color(0xFF4A4A4A),
        bad = Color(0xFF1F1F1F),
        good = Color(0xFF111111),
        moodHot = Color(0xFF111111),
        moodWarm = Color(0xFF444444),
        moodDim = Color(0xFF8A8A8A),
        enHigh = Color(0xFF111111),
        enMid = Color(0xFF555555),
        enLow = Color(0xFF888888),
        levelBg = Color(0xFFE0DDD3),
        levelInk = Color(0xFF111111),
        shellBottom = Color(0xFF2B2B2B),
        backgroundEnd = Color(0xFFE6E2D8),
        panelAlpha = 0.86f,
    )

    private val classicLcd = TerminalColors(
        ink = Color(0xFFCDE8CE),
        inkDim = Color(0xFF6F8571),
        lcdBg = Color(0xFF0F1010),
        lcdBgHi = Color(0xFF1A1B1B),
        lcdPanel = Color(0xFF212222),
        lcdDivider = Color(0xFF2E2F2E),
        accent = Color(0xFFEA5A2A),
        accentSoft = Color(0xFFFFB35D),
        bad = Color(0xFFD03832),
        good = Color(0xFF168E57),
        moodHot = Color(0xFFF15A50),
        moodWarm = Color(0xFFF0A34F),
        moodDim = Color(0xFF8F988E),
        enHigh = Color(0xFF6BD8F3),
        enMid = Color(0xFFE8E56B),
        enLow = Color(0xFFEF6A50),
        levelBg = Color(0xFFEAC6B7),
        levelInk = Color(0xFF201F1D),
        shellBottom = Color(0xFFDB4215),
        backgroundEnd = Color.Black,
        panelAlpha = 0.72f,
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
