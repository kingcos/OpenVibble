// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke

/**
 * Full-screen LCD background: vertical gradient from [TerminalPalette.lcdBg]
 * to pure black, with horizontal scanlines over it.
 *
 * Mirrors iOS `TerminalBackground` + `ScanlineOverlay` from
 * `OpenVibbleApp/UI/TerminalStyle.swift`. Rendered once at the root of each
 * screen; content sits on top in a higher ZIndex.
 */
@Composable
fun TerminalBackground(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(TerminalPalette.backgroundBrush),
    ) {
        ScanlineOverlay()
    }
}

@Composable
fun ScanlineOverlay(modifier: Modifier = Modifier) {
    val stroke = Stroke(width = 0.5f)
    val color = TerminalPalette.ink.copy(alpha = 0.05f)
    Canvas(modifier = modifier.fillMaxSize()) {
        var y = 0f
        while (y <= size.height) {
            drawLine(
                color = color,
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = stroke.width,
            )
            y += 3f
        }
    }
}
