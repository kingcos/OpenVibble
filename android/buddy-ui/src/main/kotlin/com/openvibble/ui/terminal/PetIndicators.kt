// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android parity with iOS `PetIndicator.MoodRow`. 4 hearts, filled tier drives
 * color: >=3 hot, >=2 warm, else dim.
 */
@Composable
fun MoodRow(tier: Int, modifier: Modifier = Modifier) {
    val color = when {
        tier >= 3 -> TerminalPalette.moodHot
        tier >= 2 -> TerminalPalette.moodWarm
        else -> TerminalPalette.moodDim
    }
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for (i in 0 until 4) {
            val on = i < tier
            Text(
                text = if (on) "♥" else "♡",
                color = if (on) color else TerminalPalette.moodDim,
                fontWeight = FontWeight.Bold,
                fontSize = 13.sp,
            )
        }
    }
}

@Composable
fun FedRow(filled: Int, modifier: Modifier = Modifier) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for (i in 0 until 10) {
            val on = i < filled
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .background(if (on) TerminalPalette.ink else Color.Transparent, CircleShape)
                    .border(
                        width = 1.dp,
                        color = if (on) TerminalPalette.ink else TerminalPalette.inkDim,
                        shape = CircleShape,
                    ),
            )
        }
    }
}

@Composable
fun EnergyRow(tier: Int, modifier: Modifier = Modifier) {
    val color = when {
        tier >= 4 -> TerminalPalette.enHigh
        tier >= 2 -> TerminalPalette.enMid
        else -> TerminalPalette.enLow
    }
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for (i in 0 until 5) {
            val on = i < tier
            Box(
                modifier = Modifier
                    .size(width = 11.dp, height = 8.dp)
                    .background(if (on) color else Color.Transparent)
                    .border(width = 1.dp, color = if (on) color else TerminalPalette.inkDim),
            )
        }
    }
}

@Composable
fun LevelBadge(level: Int, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(TerminalPalette.levelBg, RoundedCornerShape(5.dp))
            .padding(horizontal = 8.dp, vertical = 2.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Lv $level",
            color = TerminalPalette.levelInk,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
        )
    }
}
