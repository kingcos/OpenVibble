// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species.overlays

import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.BakedPoint
import com.openvibble.ui.species.Overlay
import com.openvibble.ui.species.OverlayPath
import com.openvibble.ui.species.OverlayTint
import com.openvibble.ui.species.OverlayVisibility

private fun gridCol(px: Int): Double = (px - 31) / 6.0
private fun gridRow(px: Int): Double = (px - 30) / 8.0

object ChonkOverlays {
    val all: Map<PersonaState, List<Overlay>> = mapOf(
        PersonaState.SLEEP to sleep,
        PersonaState.BUSY to busy,
        PersonaState.ATTENTION to attention,
        PersonaState.CELEBRATE to celebrate,
        PersonaState.DIZZY to dizzy,
        PersonaState.HEART to heart,
    )

    // SLEEP: three lazy Z-streams drift up-right over 12 ticks.
    private val sleep: List<Overlay> = listOf(
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 18),
                originRow = gridRow(6 + 20),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -2.0 / 8.0,
                phase = 0.0,
                span = 12.0,
            ),
        ),
        Overlay(
            char = "Z",
            tint = OverlayTint.White,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 24),
                originRow = gridRow(6 + 16),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -1.0 / 8.0,
                phase = 5.0,
                span = 12.0,
            ),
        ),
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 30),
                originRow = gridRow(6 + 12),
                dxPerTick = 0.5 / 6.0,
                dyPerTick = -0.5 / 8.0,
                phase = 9.0,
                span = 12.0,
            ),
        ),
    )

    // BUSY: two cog spinners (CYAN "+x*x" at 67+24/6+12, WHITE "*x+x" at 67+30/6+18).
    private val busy: List<Overlay> = run {
        val cyan = OverlayTint.Rgb565(0x07FF)
        val col1 = gridCol(67 + 24)
        val row1 = gridRow(6 + 12)
        val col2 = gridCol(67 + 30)
        val row2 = gridRow(6 + 18)
        listOf(
            Overlay(char = "+  ", tint = cyan, path = OverlayPath.Fixed(col1, row1), visibility = OverlayVisibility.TickMod(4, listOf(0))),
            Overlay(char = "x  ", tint = cyan, path = OverlayPath.Fixed(col1, row1), visibility = OverlayVisibility.TickMod(4, listOf(1))),
            Overlay(char = "*  ", tint = cyan, path = OverlayPath.Fixed(col1, row1), visibility = OverlayVisibility.TickMod(4, listOf(2))),
            Overlay(char = "x  ", tint = cyan, path = OverlayPath.Fixed(col1, row1), visibility = OverlayVisibility.TickMod(4, listOf(3))),
            Overlay(char = "*  ", tint = OverlayTint.White, path = OverlayPath.Fixed(col2, row2), visibility = OverlayVisibility.TickMod(4, listOf(0))),
            Overlay(char = "x  ", tint = OverlayTint.White, path = OverlayPath.Fixed(col2, row2), visibility = OverlayVisibility.TickMod(4, listOf(1))),
            Overlay(char = "+  ", tint = OverlayTint.White, path = OverlayPath.Fixed(col2, row2), visibility = OverlayVisibility.TickMod(4, listOf(2))),
            Overlay(char = "x  ", tint = OverlayTint.White, path = OverlayPath.Fixed(col2, row2), visibility = OverlayVisibility.TickMod(4, listOf(3))),
        )
    }

    // ATTENTION: three "!" flashers (heavy alert wobble).
    private val attention: List<Overlay> = listOf(
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xFFE0),
            path = OverlayPath.Fixed(col = gridCol(67 - 6), row = gridRow(6)),
            visibility = OverlayVisibility.TickMod(period = 4, activeTicks = listOf(2, 3)),
        ),
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xF800),
            path = OverlayPath.Fixed(col = gridCol(67 + 6), row = gridRow(6 + 4)),
            visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(3, 4, 5)),
        ),
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xFFE0),
            path = OverlayPath.Fixed(col = gridCol(67 - 14), row = gridRow(6 + 6)),
            visibility = OverlayVisibility.TickMod(period = 8, activeTicks = listOf(4, 5, 6, 7)),
        ),
    )

    // CELEBRATE: 7 confetti streams with wider spread (x = 67-42+i*14, span=24, phase=i*9).
    private val celebrate: List<Overlay> = run {
        val palette: List<OverlayTint> = listOf(
            OverlayTint.Rgb565(0xFFE0),
            OverlayTint.Rgb565(0xF810),
            OverlayTint.Rgb565(0x07FF),
            OverlayTint.White,
            OverlayTint.Rgb565(0x07E0),
            OverlayTint.Rgb565(0xA01F),
        )
        (0 until 7).map { i ->
            Overlay(
                char = if (i % 2 == 0) "o" else "*",
                tint = palette[i % 6],
                path = OverlayPath.Linear(
                    originCol = gridCol(67 - 42 + i * 14),
                    originRow = gridRow(6 - 8),
                    dxPerTick = 0.0,
                    dyPerTick = 2.0 / 8.0,
                    phase = (i * 9).toDouble(),
                    span = 24.0,
                ),
            )
        }
    }

    // DIZZY: three orbiting symbols in a wider ellipse (OX/OY magnitudes 6/9 vs 5/7).
    private val dizzy: List<Overlay> = run {
        val ox = intArrayOf(0, 6, 9, 6, 0, -6, -9, -6)
        val oy = intArrayOf(-6, -4, 0, 4, 6, 4, 0, -4)
        fun orbitPoints(startOffset: Int): List<BakedPoint> =
            (0 until 8).map { i ->
                val idx = (i + startOffset) % 8
                BakedPoint(
                    col = gridCol(67 + ox[idx] - 2),
                    row = gridRow(6 + 6 + oy[idx]),
                )
            }
        listOf(
            Overlay(char = "*", tint = OverlayTint.Rgb565(0x07FF), path = OverlayPath.Baked(orbitPoints(0))),
            Overlay(char = "*", tint = OverlayTint.Rgb565(0xFFE0), path = OverlayPath.Baked(orbitPoints(3))),
            Overlay(char = "+", tint = OverlayTint.White, path = OverlayPath.Baked(orbitPoints(5))),
        )
    }

    // HEART: 6 heart-rise streams over 18 ticks (extra stream vs default 5/16).
    private val heart: List<Overlay> = (0 until 6).map { i ->
        Overlay(
            char = "v",
            tint = OverlayTint.Rgb565(0xF810),
            path = OverlayPath.Linear(
                originCol = gridCol(67 - 22 + i * 8),
                originRow = gridRow(6 + 16),
                dxPerTick = 0.0,
                dyPerTick = -1.0 / 8.0,
                phase = (i * 3).toDouble(),
                span = 18.0,
            ),
        )
    }
}
