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

object RobotOverlays {
    val all: Map<PersonaState, List<Overlay>> = mapOf(
        PersonaState.SLEEP to sleep,
        PersonaState.IDLE to idle,
        PersonaState.BUSY to busy,
        PersonaState.ATTENTION to attention,
        PersonaState.CELEBRATE to celebrate,
        PersonaState.DIZZY to dizzy,
        PersonaState.HEART to heart,
    )

    // SLEEP: three Z-streams drift up-right over 10 ticks (low-power beeps), mid Z is CYAN.
    private val sleep: List<Overlay> = listOf(
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 20),
                originRow = gridRow(6 + 18),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -2.0 / 8.0,
                phase = 0.0,
                span = 10.0,
            ),
        ),
        Overlay(
            char = "Z",
            tint = OverlayTint.Rgb565(0x07FF),
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 26),
                originRow = gridRow(6 + 14),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -1.0 / 8.0,
                phase = 4.0,
                span = 10.0,
            ),
        ),
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 16),
                originRow = gridRow(6 + 10),
                dxPerTick = 0.5 / 6.0,
                dyPerTick = -0.5 / 8.0,
                phase = 7.0,
                span = 10.0,
            ),
        ),
    )

    // IDLE: RED antenna LED blink at (67-1, y=26) — half-duty 8-tick period.
    private val idle: List<Overlay> = listOf(
        Overlay(
            char = ".",
            tint = OverlayTint.Rgb565(0xF800),
            path = OverlayPath.Fixed(col = gridCol(67 - 1), row = gridRow(26)),
            visibility = OverlayVisibility.TickMod(period = 8, activeTicks = listOf(4, 5, 6, 7)),
        ),
    )

    // BUSY: GREEN binary stream at (67+22, 6+14) cycling 1  /10 /101/010/10 /1  .
    private val busy: List<Overlay> = run {
        val col = gridCol(67 + 22)
        val row = gridRow(6 + 14)
        val green = OverlayTint.Rgb565(0x07E0)
        listOf(
            Overlay(char = "1  ", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(0))),
            Overlay(char = "10 ", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(1))),
            Overlay(char = "101", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(2))),
            Overlay(char = "010", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(3))),
            Overlay(char = "10 ", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(4))),
            Overlay(char = "1  ", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(5))),
        )
    }

    // ATTENTION: YEL "!" + RED "!" + RED "*" (antenna warning light).
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
            char = "*",
            tint = OverlayTint.Rgb565(0xF800),
            path = OverlayPath.Fixed(col = gridCol(67 - 1), row = gridRow(26)),
            visibility = OverlayVisibility.TickMod(period = 4, activeTicks = listOf(2, 3)),
        ),
    )

    // CELEBRATE: 6 spark streams, "+"/ "*" alternation, YEL/CYAN/GREEN/WHITE/PURPLE palette.
    private val celebrate: List<Overlay> = run {
        val palette: List<OverlayTint> = listOf(
            OverlayTint.Rgb565(0xFFE0),
            OverlayTint.Rgb565(0x07FF),
            OverlayTint.Rgb565(0x07E0),
            OverlayTint.White,
            OverlayTint.Rgb565(0xA01F),
        )
        (0 until 6).map { i ->
            Overlay(
                char = if (i % 2 == 0) "+" else "*",
                tint = palette[i % 5],
                path = OverlayPath.Linear(
                    originCol = gridCol(67 - 36 + i * 14),
                    originRow = gridRow(0),
                    dxPerTick = 0.0,
                    dyPerTick = 2.0 / 8.0,
                    phase = (i * 11).toDouble(),
                    span = 22.0,
                ),
            )
        }
    }

    // DIZZY: YEL "?" and RED "x" orbit (default OY+6 anchor).
    private val dizzy: List<Overlay> = run {
        val ox = intArrayOf(0, 5, 7, 5, 0, -5, -7, -5)
        val oy = intArrayOf(-5, -3, 0, 3, 5, 3, 0, -3)
        fun orbitPoints(startOffset: Int): List<BakedPoint> =
            (0 until 8).map { i ->
                val idx = (i + startOffset) % 8
                BakedPoint(
                    col = gridCol(67 + ox[idx] - 2),
                    row = gridRow(6 + 6 + oy[idx]),
                )
            }
        listOf(
            Overlay(char = "?", tint = OverlayTint.Rgb565(0xFFE0), path = OverlayPath.Baked(orbitPoints(0))),
            Overlay(char = "x", tint = OverlayTint.Rgb565(0xF800), path = OverlayPath.Baked(orbitPoints(4))),
        )
    }

    private val heart: List<Overlay> = (0 until 5).map { i ->
        Overlay(
            char = "v",
            tint = OverlayTint.Rgb565(0xF810),
            path = OverlayPath.Linear(
                originCol = gridCol(67 - 20 + i * 8),
                originRow = gridRow(6 + 16),
                dxPerTick = 0.0,
                dyPerTick = -1.0 / 8.0,
                phase = (i * 4).toDouble(),
                span = 16.0,
            ),
        )
    }
}
