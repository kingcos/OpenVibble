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

object DragonOverlays {
    val all: Map<PersonaState, List<Overlay>> = mapOf(
        PersonaState.SLEEP to sleep,
        PersonaState.IDLE to idle,
        PersonaState.BUSY to busy,
        PersonaState.ATTENTION to attention,
        PersonaState.CELEBRATE to celebrate,
        PersonaState.DIZZY to dizzy,
        PersonaState.HEART to heart,
    )

    // SLEEP: two Z-streams + one smoke ring drifting up.
    private val sleep: List<Overlay> = listOf(
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 22),
                originRow = gridRow(6 + 18),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -2.0 / 8.0,
                phase = 0.0,
                span = 10.0,
            ),
        ),
        Overlay(
            char = "Z",
            tint = OverlayTint.White,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 28),
                originRow = gridRow(6 + 12),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -1.0 / 8.0,
                phase = 4.0,
                span = 10.0,
            ),
        ),
        Overlay(
            char = "o",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 18),
                originRow = gridRow(6 + 16),
                dxPerTick = 0.0,
                dyPerTick = -1.0 / 8.0,
                phase = 7.0,
                span = 12.0,
            ),
        ),
    )

    // IDLE: nostril smoke "." / "o" alternating as it rises (pose-gating dropped per approved rules).
    private val idle: List<Overlay> = listOf(
        Overlay(
            char = ".",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 0),
                originRow = gridRow(6 - 4),
                dxPerTick = 0.0,
                dyPerTick = -1.0 / 8.0,
                phase = 0.0,
                span = 8.0,
            ),
            visibility = OverlayVisibility.TickMod(period = 2, activeTicks = listOf(0)),
        ),
        Overlay(
            char = "o",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 0),
                originRow = gridRow(6 - 4),
                dxPerTick = 0.0,
                dyPerTick = -1.0 / 8.0,
                phase = 1.0,
                span = 8.0,
            ),
            visibility = OverlayVisibility.TickMod(period = 2, activeTicks = listOf(1)),
        ),
    )

    // BUSY: YEL gold-coin ticker + WHITE sparkle.
    private val busy: List<Overlay> = run {
        val col = gridCol(67 + 22)
        val row = gridRow(6 + 14)
        val yel = OverlayTint.Rgb565(0xFFE0)
        listOf(
            Overlay(char = "$  ", tint = yel, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(0))),
            Overlay(char = "$$ ", tint = yel, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(1))),
            Overlay(char = "$$$", tint = yel, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(2))),
            Overlay(char = " $$", tint = yel, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(3))),
            Overlay(char = "  $", tint = yel, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(4))),
            Overlay(
                char = "*",
                tint = OverlayTint.White,
                path = OverlayPath.Fixed(col = gridCol(67 + 24), row = gridRow(6 + 10)),
                visibility = OverlayVisibility.TickMod(period = 4, activeTicks = listOf(2, 3)),
            ),
        )
    }

    // ATTENTION: YEL "!", RED "!", and a YEL flame-puff that drifts up (pose gating dropped).
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
            char = "^",
            tint = OverlayTint.Rgb565(0xFFE0),
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 18),
                originRow = gridRow(6 + 12),
                dxPerTick = 0.0,
                dyPerTick = -2.0 / 8.0,
                phase = 0.0,
                span = 4.0,
            ),
        ),
    )

    // CELEBRATE: 6 confetti streams, "*"/"$" alternation.
    private val celebrate: List<Overlay> = run {
        val palette: List<OverlayTint> = listOf(
            OverlayTint.Rgb565(0xFFE0),
            OverlayTint.Rgb565(0xF810),
            OverlayTint.Rgb565(0x07FF),
            OverlayTint.White,
            OverlayTint.Rgb565(0x07E0),
        )
        (0 until 6).map { i ->
            Overlay(
                char = if (i % 2 == 0) "*" else "$",
                tint = palette[i % 5],
                path = OverlayPath.Linear(
                    originCol = gridCol(67 - 36 + i * 14),
                    originRow = gridRow(6 - 6),
                    dxPerTick = 0.0,
                    dyPerTick = 2.0 / 8.0,
                    phase = (i * 11).toDouble(),
                    span = 22.0,
                ),
            )
        }
    }

    // DIZZY: CYAN "*", YEL "*", WHITE "$" orbit.
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
            Overlay(char = "*", tint = OverlayTint.Rgb565(0x07FF), path = OverlayPath.Baked(orbitPoints(0))),
            Overlay(char = "*", tint = OverlayTint.Rgb565(0xFFE0), path = OverlayPath.Baked(orbitPoints(4))),
            Overlay(char = "$", tint = OverlayTint.White, path = OverlayPath.Baked(orbitPoints(2))),
        )
    }

    // HEART: 5 heart-rise streams + lovesick dim smoke ring rising faster.
    private val heart: List<Overlay> = run {
        val rises = (0 until 5).map { i ->
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
        val ring = Overlay(
            char = "o",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 14),
                originRow = gridRow(6 + 14),
                dxPerTick = 0.0,
                dyPerTick = -2.0 / 8.0,
                phase = 0.0,
                span = 9.0,
            ),
        )
        rises + ring
    }
}
