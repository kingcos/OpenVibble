// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android parity with iOS `TerminalPanel`. A rounded-rectangle card with an
 * optional `$ title` header; can be collapsible with an animated expand.
 *
 * Pads 12.dp internally, draws a 1.dp border tinted by [accent] at 40% alpha,
 * and the fill uses [TerminalPalette.panelFill].
 */
@Composable
fun TerminalPanel(
    modifier: Modifier = Modifier,
    title: String? = null,
    accent: Color = TerminalPalette.ink,
    collapsible: Boolean = false,
    collapsedByDefault: Boolean = false,
    content: @Composable () -> Unit,
) {
    var isExpanded by remember(collapsedByDefault) { mutableStateOf(!collapsedByDefault) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(TerminalPalette.panelFill, RoundedCornerShape(10.dp))
            .border(
                BorderStroke(1.dp, accent.copy(alpha = 0.4f)),
                RoundedCornerShape(10.dp),
            )
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (collapsible) {
            val interaction = remember { MutableInteractionSource() }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(
                        interactionSource = interaction,
                        indication = null,
                    ) { isExpanded = !isExpanded },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = buildPromptHeader(title),
                    color = accent,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    text = if (isExpanded) "v" else ">",
                    color = accent,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.Bold,
                    fontSize = 10.sp,
                )
            }
            AnimatedVisibility(
                visible = isExpanded,
                enter = expandVertically(tween(150)) + fadeIn(tween(150)),
                exit = shrinkVertically(tween(150)) + fadeOut(tween(150)),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) { content() }
            }
        } else {
            if (title != null) {
                Text(
                    text = buildPromptHeader(title),
                    color = accent,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                )
            }
            Column(modifier = Modifier.fillMaxWidth()) { content() }
        }
    }
}

private fun buildPromptHeader(title: String?): String =
    if (title == null) "$ " else "$ $title"
