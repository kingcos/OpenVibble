// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.terminal

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Port of iOS `TerminalHeaderButtonStyle`. Rounded, mono label, opacity
 * shifts while pressed. Use [fillMaxWidth] when [fill] = true.
 */
@Composable
fun TerminalHeaderButton(
    label: String,
    modifier: Modifier = Modifier,
    fill: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val bg = TerminalPalette.lcdPanel.copy(alpha = if (pressed) 0.9f else 0.7f)

    Row(
        modifier = modifier
            .then(if (fill) Modifier.fillMaxWidth() else Modifier)
            .background(bg, RoundedCornerShape(6.dp))
            .border(
                BorderStroke(1.dp, TerminalPalette.inkDim.copy(alpha = 0.55f)),
                RoundedCornerShape(6.dp),
            )
            .clickable(
                enabled = enabled,
                interactionSource = interaction,
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 8.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = TerminalPalette.ink.copy(alpha = if (enabled) 1f else 0.5f),
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.SemiBold,
            fontSize = 11.sp,
            textAlign = TextAlign.Center,
            modifier = if (fill) Modifier.fillMaxWidth() else Modifier,
        )
    }
}

/**
 * Port of iOS `TerminalTabBar`. Horizontal pill row where the selected tab
 * inverts (ink fill, lcdBg text) and others sit on a dim panel.
 */
data class TerminalTab(val id: String, val label: String)

@Composable
fun TerminalTabBar(
    tabs: List<TerminalTab>,
    selection: String,
    modifier: Modifier = Modifier,
    onSelect: (String) -> Unit,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        for (tab in tabs) {
            val selected = tab.id == selection
            Row(
                modifier = Modifier
                    .background(
                        if (selected) TerminalPalette.ink else TerminalPalette.lcdPanel.copy(alpha = 0.7f),
                        RoundedCornerShape(6.dp),
                    )
                    .border(
                        BorderStroke(1.dp, TerminalPalette.inkDim.copy(alpha = 0.5f)),
                        RoundedCornerShape(6.dp),
                    )
                    .clickable { onSelect(tab.id) }
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = tab.label,
                    color = if (selected) TerminalPalette.lcdBg else TerminalPalette.ink,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 11.sp,
                    letterSpacing = 1.sp,
                )
            }
        }
    }
}
