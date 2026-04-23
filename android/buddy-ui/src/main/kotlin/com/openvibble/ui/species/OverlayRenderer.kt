// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

import kotlin.math.cos
import kotlin.math.sin

data class OverlayPoint(val col: Double, val row: Double)

object OverlayRenderer {
    fun position(path: OverlayPath, tick: Int): OverlayPoint {
        val t = tick.toDouble()
        return when (path) {
            is OverlayPath.Fixed -> OverlayPoint(path.col, path.row)
            is OverlayPath.DriftUpRight -> {
                val p = (t * path.speed + path.phase).mod(path.span)
                OverlayPoint(col = p, row = -p * 0.5 + path.span * 0.5)
            }
            is OverlayPath.Orbit -> {
                val angle = t * path.speed + path.phase
                OverlayPoint(col = cos(angle) * path.radius, row = sin(angle) * path.radius)
            }
            is OverlayPath.Bobble -> OverlayPoint(
                col = path.col,
                row = path.row + sin(t * path.speed) * path.amp,
            )
            is OverlayPath.Baked -> {
                if (path.points.isEmpty()) OverlayPoint(0.0, 0.0)
                else {
                    val idx = ((tick % path.points.size) + path.points.size) % path.points.size
                    val pt = path.points[idx]
                    OverlayPoint(pt.col, pt.row)
                }
            }
            is OverlayPath.Linear -> {
                val p = (t + path.phase).mod(path.span)
                OverlayPoint(
                    col = path.originCol + p * path.dxPerTick,
                    row = path.originRow + p * path.dyPerTick,
                )
            }
        }
    }

    fun isVisible(visibility: OverlayVisibility, tick: Int): Boolean = when (visibility) {
        OverlayVisibility.Always -> true
        is OverlayVisibility.TickMod -> {
            val bucket = ((tick % visibility.period) + visibility.period) % visibility.period
            bucket in visibility.activeTicks
        }
    }
}
