// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species.overlays

import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.Overlay
import com.openvibble.ui.species.OverlayPath
import com.openvibble.ui.species.OverlayTint
import com.openvibble.ui.species.OverlayVisibility

private fun gridCol(px: Int): Double = (px - 31) / 6.0
private fun gridRow(px: Int): Double = (px - 30) / 8.0

object GhostOverlays {
    val all: Map<PersonaState, List<Overlay>> = mapOf(
        PersonaState.SLEEP to sleep,
        PersonaState.BUSY to busy,
        PersonaState.ATTENTION to attention,
        PersonaState.CELEBRATE to celebrate,
        PersonaState.DIZZY to CapybaraOverlays.all[PersonaState.DIZZY]!!,
        PersonaState.HEART to CapybaraOverlays.all[PersonaState.HEART]!!,
    )

    // SLEEP: three Z-streams drift up-right over 12 ticks (identical shape to cat, different phases).
    private val sleep: List<Overlay> = listOf(
        Overlay(
            char = "z",
            tint = OverlayTint.Dim,
            path = OverlayPath.Linear(
                originCol = gridCol(67 + 18),
                originRow = gridRow(6 + 16),
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
                originRow = gridRow(6 + 12),
                dxPerTick = 1.0 / 6.0,
                dyPerTick = -1.0 / 8.0,
                phase = 4.0,
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
                phase = 8.0,
                span = 12.0,
            ),
        ),
    )

    // BUSY: BOO ticker (same chars as duck's BUBBLES) in CYAN.
    private val busy: List<Overlay> = run {
        val col = gridCol(67 + 22)
        val row = gridRow(6 + 14)
        val cyan = OverlayTint.Rgb565(0x07FF)
        listOf(
            Overlay(char = "o  ", tint = cyan, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(0))),
            Overlay(char = "oO ", tint = cyan, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(1))),
            Overlay(char = "oOo", tint = cyan, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(2))),
            Overlay(char = " Oo", tint = cyan, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(3))),
            Overlay(char = "  o", tint = cyan, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(4))),
        )
    }

    // ATTENTION: first flasher at 67-6 (ghost-specific x offset).
    private val attention: List<Overlay> = listOf(
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xFFE0),
            path = OverlayPath.Fixed(col = gridCol(67 - 6), row = gridRow(6)),
            visibility = OverlayVisibility.TickMod(period = 4, activeTicks = listOf(2, 3)),
        ),
        Overlay(
            char = "!",
            tint = OverlayTint.Rgb565(0xFFE0),
            path = OverlayPath.Fixed(col = gridCol(67 + 6), row = gridRow(6 + 4)),
            visibility = OverlayVisibility.TickMod(period = 6, activeTicks = listOf(3, 4, 5)),
        ),
    )

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
                char = if (i % 2 == 0) "*" else "o",
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
}
