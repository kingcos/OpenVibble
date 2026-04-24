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

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private fun gridCol(px: Int): Double = (px - 31) / 6.0
private fun gridRow(px: Int): Double = (px - 30) / 8.0

object CatOverlays {
    val all: Map<PersonaState, List<Overlay>> by lazy { mapOf(
        PersonaState.SLEEP to sleep,
        PersonaState.BUSY to busy,
        PersonaState.ATTENTION to attention,
        PersonaState.CELEBRATE to celebrate,
        PersonaState.DIZZY to dizzy,
        PersonaState.HEART to heart,
        // IDLE has no overlays per firmware
    ) }

    // SLEEP: three Z-streams drift up-right over 12 ticks
    private val sleep: List<Overlay> = listOf(
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 18),
                originRow = gridRow(6 + 18),
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
                originRow = gridRow(6 + 14),
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
                originCol = gridCol(67 + 14),
                originRow = gridRow(6 + 8),
                dxPerTick = 0.5 / 6.0,
                dyPerTick = -0.5 / 8.0,
                phase = 9.0,
                span = 12.0,
            ),
        ),
    )

    // BUSY: DOTS ticker — 6 chars at fixed cursor, cycled by t%6.
    // tick%6==5 is blank so no overlay needed for that slot.
    private val busy: List<Overlay> = run {
        val col = gridCol(67 + 22)
        val row = gridRow(6 + 14)
        listOf(
            Overlay(
                char = ".  ",
                tint = OverlayTint.White,
                path = OverlayPath.Fixed(col = col, row = row),
                visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(0)),
            ),
            Overlay(
                char = ".. ",
                tint = OverlayTint.White,
                path = OverlayPath.Fixed(col = col, row = row),
                visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(1)),
            ),
            Overlay(
                char = "...",
                tint = OverlayTint.White,
                path = OverlayPath.Fixed(col = col, row = row),
                visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(2)),
            ),
            Overlay(
                char = " ..",
                tint = OverlayTint.White,
                path = OverlayPath.Fixed(col = col, row = row),
                visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(3)),
            ),
            Overlay(
                char = "  .",
                tint = OverlayTint.White,
                path = OverlayPath.Fixed(col = col, row = row),
                visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(4)),
            ),
        )
    }

    // ATTENTION: two "!" flashers at fixed positions.
    private val attention: List<Overlay> = listOf(
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xFFE0), // BUDDY_YEL
            path = OverlayPath.Fixed(col = gridCol(67 - 4), row = gridRow(6)),
            visibility = OverlayVisibility.TickMod(period = 4, activeTicks = listOf(2, 3)),
        ),
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xFFE0), // BUDDY_YEL
            path = OverlayPath.Fixed(col = gridCol(67 + 4), row = gridRow(6 + 4)),
            visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(3, 4, 5)),
        ),
    )

    // CELEBRATE: 6 confetti streams drifting down.
    private val celebrate: List<Overlay> = run {
        val palette: List<OverlayTint> = listOf(
            OverlayTint.Rgb565(0xFFE0), // YEL
            OverlayTint.Rgb565(0xF810), // HEART
            OverlayTint.Rgb565(0x07FF), // CYAN
            OverlayTint.White,
            OverlayTint.Rgb565(0x07E0), // GREEN
        )
        (0 until 6).map { i ->
            Overlay(
                char = if (i % 2 == 0) "*" else ".",
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

    // DIZZY: two orbiting "*" stars using pre-baked 8-position table.
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
            Overlay(
                char = "*",
                tint = OverlayTint.Rgb565(0x07FF),
                path = OverlayPath.Baked(orbitPoints(0)),
            ),
            Overlay(
                char = "*",
                tint = OverlayTint.Rgb565(0xFFE0),
                path = OverlayPath.Baked(orbitPoints(4)),
            ),
        )
    }

    // HEART: 5 heart-rise streams over 16 ticks.
    private val heart: List<Overlay> = (0 until 5).map { i ->
        Overlay(
            char = "v",
            tint = OverlayTint.Rgb565(0xF810), // BUDDY_HEART
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
