// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.PathEffect

/**
 * Android parity with iOS `ButtonCheatSheet` — the on-screen handheld button
 * legend that appears in both onboarding and settings. Supports three badge
 * styles: filled letter, dashed-outline letter (long press), filled symbol.
 */
sealed class CheatBadge {
    data class Text(val value: String) : CheatBadge()
    data class LongPress(val value: String) : CheatBadge()
    data class Icon(val symbol: String) : CheatBadge()
}

data class CheatRow(val badge: CheatBadge, val body: String)

@Composable
fun ButtonCheatSheet(
    rows: List<CheatRow>,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        for (row in rows) CheatSheetRow(row)
    }
}

@Composable
private fun CheatSheetRow(row: CheatRow) {
    Row(
        modifier = Modifier.wrapContentHeight(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        BadgeView(row.badge)
        Text(
            text = row.body,
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
            lineHeight = 18.sp,
            modifier = Modifier
                .height(24.dp)
                .wrapContentHeight(Alignment.Top),
        )
    }
}

@Composable
private fun BadgeView(badge: CheatBadge) {
    when (badge) {
        is CheatBadge.Text -> FilledBadge(badge.value)
        is CheatBadge.Icon -> FilledBadge(badge.symbol)
        is CheatBadge.LongPress -> DashedBadge(badge.value)
    }
}

@Composable
private fun FilledBadge(text: String) {
    Box(
        modifier = Modifier
            .size(width = 38.dp, height = 24.dp)
            .background(TerminalPalette.ink, RoundedCornerShape(5.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = TerminalPalette.lcdBg,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun DashedBadge(text: String) {
    Box(
        modifier = Modifier
            .size(width = 38.dp, height = 24.dp)
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.8f), RoundedCornerShape(5.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) { drawDashedBorder() }
        Text(
            text = text,
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
        )
    }
}

private fun DrawScope.drawDashedBorder() {
    val r = 5.dp.toPx()
    val path = Path().apply {
        addRoundRect(
            androidx.compose.ui.geometry.RoundRect(
                rect = androidx.compose.ui.geometry.Rect(Offset.Zero, size),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(r, r),
            ),
        )
    }
    drawPath(
        path = path,
        color = TerminalPalette.ink,
        style = Stroke(
            width = 1.2.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx())),
        ),
    )
}
