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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

enum class TerminalActionButtonRole {
    Neutral,
    Primary,
    Danger,
    Selected,
}

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
 * Shared terminal button used by Android settings/help/species screens.
 * Keeps touch target, corner radius, border, typography, and pressed opacity
 * consistent across top actions and full-width row actions.
 */
@Composable
fun TerminalActionButton(
    label: String,
    modifier: Modifier = Modifier,
    secondaryLabel: String? = null,
    leading: String? = null,
    trailing: String? = null,
    fill: Boolean = false,
    role: TerminalActionButtonRole = TerminalActionButtonRole.Neutral,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shape = RoundedCornerShape(8.dp)
    val colors = terminalActionColors(role = role, pressed = pressed, enabled = enabled)

    Row(
        modifier = modifier
            .then(if (fill) Modifier.fillMaxWidth() else Modifier)
            .heightIn(min = 36.dp)
            .background(colors.background, shape)
            .border(BorderStroke(1.dp, colors.border), shape)
            .clickable(
                enabled = enabled,
                interactionSource = interaction,
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (leading != null) {
            TerminalActionText(text = leading, color = colors.foreground, bold = true)
        }
        Column(
            modifier = if (fill) Modifier.weight(1f) else Modifier,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = label,
                color = colors.foreground,
                fontFamily = TerminalFonts.mono,
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
                textAlign = if (fill && trailing == null && leading == null) TextAlign.Center else TextAlign.Start,
                modifier = if (fill && secondaryLabel == null) Modifier.fillMaxWidth() else Modifier,
            )
            if (!secondaryLabel.isNullOrEmpty()) {
                Text(
                    text = secondaryLabel,
                    color = colors.foreground.copy(alpha = 0.72f),
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.Normal,
                    fontSize = 10.sp,
                )
            }
        }
        if (trailing != null) {
            TerminalActionText(text = trailing, color = colors.foreground, bold = true)
        }
    }
}

@Composable
private fun TerminalActionText(
    text: String,
    color: Color,
    bold: Boolean,
) {
    Text(
        text = text,
        color = color,
        fontFamily = TerminalFonts.mono,
        fontWeight = if (bold) FontWeight.Bold else FontWeight.SemiBold,
        fontSize = 12.sp,
        textAlign = TextAlign.Center,
    )
}

private data class TerminalActionColors(
    val background: Color,
    val border: Color,
    val foreground: Color,
)

private fun terminalActionColors(
    role: TerminalActionButtonRole,
    pressed: Boolean,
    enabled: Boolean,
): TerminalActionColors {
    val enabledAlpha = if (enabled) 1f else 0.45f
    val pressedBoost = if (pressed) 0.12f else 0f
    return when (role) {
        TerminalActionButtonRole.Neutral -> TerminalActionColors(
            background = TerminalPalette.lcdPanel.copy(alpha = (0.68f + pressedBoost).coerceAtMost(0.88f)),
            border = TerminalPalette.inkDim.copy(alpha = 0.52f * enabledAlpha),
            foreground = TerminalPalette.ink.copy(alpha = enabledAlpha),
        )
        TerminalActionButtonRole.Primary -> TerminalActionColors(
            background = TerminalPalette.accent.copy(alpha = (0.82f + pressedBoost).coerceAtMost(0.95f)),
            border = Color.Black.copy(alpha = 0.3f),
            foreground = Color.White.copy(alpha = enabledAlpha),
        )
        TerminalActionButtonRole.Danger -> TerminalActionColors(
            background = TerminalPalette.lcdPanel.copy(alpha = (0.62f + pressedBoost).coerceAtMost(0.82f)),
            border = TerminalPalette.bad.copy(alpha = 0.5f * enabledAlpha),
            foreground = TerminalPalette.bad.copy(alpha = enabledAlpha),
        )
        TerminalActionButtonRole.Selected -> TerminalActionColors(
            background = TerminalPalette.ink.copy(alpha = if (pressed) 0.88f else 1f),
            border = TerminalPalette.inkDim.copy(alpha = 0.55f),
            foreground = TerminalPalette.lcdBg.copy(alpha = enabledAlpha),
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
