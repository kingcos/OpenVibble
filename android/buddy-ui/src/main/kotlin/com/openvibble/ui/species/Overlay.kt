// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

sealed class OverlayTint {
    /** Firmware BUDDY_DIM — half-luminance white. */
    data object Dim : OverlayTint()
    /** Firmware BUDDY_WHITE — pure white. */
    data object White : OverlayTint()
    /** Follows the current state's bodyColor. */
    data object Body : OverlayTint()
    data class Rgb565(val raw: Int) : OverlayTint()
}

data class BakedPoint(val col: Double, val row: Double)

sealed class OverlayPath {
    data class DriftUpRight(val speed: Double, val phase: Double, val span: Double) : OverlayPath()
    data class Orbit(val radius: Double, val speed: Double, val phase: Double) : OverlayPath()
    data class Fixed(val col: Double, val row: Double) : OverlayPath()
    data class Bobble(val col: Double, val row: Double, val amp: Double, val speed: Double) : OverlayPath()
    data class Baked(val points: List<BakedPoint>) : OverlayPath()
    data class Linear(
        val originCol: Double,
        val originRow: Double,
        val dxPerTick: Double,
        val dyPerTick: Double,
        val phase: Double,
        val span: Double,
    ) : OverlayPath()
}

sealed class OverlayVisibility {
    data object Always : OverlayVisibility()
    /**
     * Visible when `tick % period` is in `activeTicks`. Models firmware gates
     * like `if (t/2) & 1` → `TickMod(period = 4, activeTicks = [2, 3])`.
     */
    data class TickMod(val period: Int, val activeTicks: List<Int>) : OverlayVisibility()
}

data class Overlay(
    val char: String,
    val tint: OverlayTint,
    val path: OverlayPath,
    val visibility: OverlayVisibility = OverlayVisibility.Always,
)
