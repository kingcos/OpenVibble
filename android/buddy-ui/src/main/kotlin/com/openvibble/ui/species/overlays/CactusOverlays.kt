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

/**
 * Cactus shares the capybara sleep/attention/dizzy/heart overlays but swaps
 * the BUSY ticker to GREEN and the CELEBRATE palette slot to PURPLE with an
 * "o"/"*" char alternation instead of "."/"*".
 */
object CactusOverlays {
    val all: Map<PersonaState, List<Overlay>> by lazy {
        CapybaraOverlays.all.toMutableMap().apply {
        this[PersonaState.BUSY] = busy
        this[PersonaState.CELEBRATE] = celebrate
        }
    }

    private val busy: List<Overlay> = run {
        val col = gridCol(67 + 22)
        val row = gridRow(6 + 14)
        val green = OverlayTint.Rgb565(0x07E0)
        listOf(
            Overlay(char = ".  ", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(0))),
            Overlay(char = ".. ", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(1))),
            Overlay(char = "...", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(2))),
            Overlay(char = " ..", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(3))),
            Overlay(char = "  .", tint = green, path = OverlayPath.Fixed(col, row), visibility = OverlayVisibility.TickMod(6, listOf(4))),
        )
    }

    private val celebrate: List<Overlay> = run {
        val palette: List<OverlayTint> = listOf(
            OverlayTint.Rgb565(0xFFE0),
            OverlayTint.Rgb565(0xF810),
            OverlayTint.Rgb565(0x07FF),
            OverlayTint.White,
            OverlayTint.Rgb565(0xA01F), // PURPLE
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
