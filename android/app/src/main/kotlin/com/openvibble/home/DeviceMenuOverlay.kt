// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette

/**
 * Android parity with iOS `DeviceMenuOverlay`. Terminal-style overlay
 * mirroring the firmware's in-device menu tree (MENU → SETTINGS → RESET).
 * Purely local — no BLE traffic.
 *
 * Leaves a [bottomReservedHeight] transparent gap so the handheld A/B/log
 * bar stays tappable while the menu is open.
 */
@Composable
fun DeviceMenuOverlay(
    state: DeviceMenuState,
    bottomReservedHeight: Dp,
    maxPanelWidth: Dp,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(
        modifier = modifier.fillMaxSize(),
    ) {
        val availableHeight = if (maxHeight > bottomReservedHeight) maxHeight - bottomReservedHeight else maxHeight
        val panelWidth = if (maxWidth > maxPanelWidth) maxPanelWidth else maxWidth
        val preferredHeight = availableHeight * 0.58f
        val panelHeight = when {
            availableHeight < 260.dp -> availableHeight
            preferredHeight < 260.dp -> 260.dp
            preferredHeight > 420.dp -> 420.dp
            else -> preferredHeight
        }

        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = bottomReservedHeight)
                .width(panelWidth)
                .height(panelHeight)
                .background(
                    TerminalPalette.lcdBg.copy(alpha = 0.96f),
                    RoundedCornerShape(topStart = 18.dp, topEnd = 18.dp),
                )
                .padding(horizontal = 18.dp)
                .padding(top = 16.dp, bottom = 14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Header(state)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(TerminalPalette.lcdDivider),
            )
            val ctx = LocalContext.current
            val clockRotLabels = ClockRotLabels(
                portrait = stringResource(R.string.device_menu_clock_rot_portrait),
                landscape = stringResource(R.string.device_menu_clock_rot_landscape),
                auto = stringResource(R.string.device_menu_clock_rot_auto),
            )
            val onOffLabels = OnOffLabels(
                on = stringResource(R.string.device_menu_value_on),
                off = stringResource(R.string.device_menu_value_off),
            )
            when {
                state.resetOpen -> SectionList(
                    titleLabel = stringResource(R.string.device_menu_section_reset),
                    rows = resetRows(ctx),
                    selected = state.resetIndex,
                )
                state.settingsOpen -> SectionList(
                    titleLabel = stringResource(R.string.device_menu_section_settings),
                    rows = settingsRows(ctx, state, clockRotLabels, onOffLabels),
                    selected = state.settingsIndex,
                )
                state.menuOpen -> SectionList(
                    titleLabel = stringResource(R.string.device_menu_section_menu),
                    rows = menuRows(ctx),
                    selected = state.menuIndex,
                )
            }
            Spacer(Modifier.weight(1f))
            Footer()
        }
    }
}

@Composable
private fun Header(state: DeviceMenuState) {
    val crumb = when {
        state.resetOpen -> stringResource(R.string.device_menu_section_reset)
        state.settingsOpen -> stringResource(R.string.device_menu_section_settings)
        else -> stringResource(R.string.device_menu_section_menu)
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = stringResource(R.string.device_menu_title),
            color = TerminalPalette.ink,
            fontSize = 18.sp,
            fontWeight = FontWeight.ExtraBold,
            style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = crumb,
            color = TerminalPalette.inkDim,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
        )
    }
}

private data class DisplayRow(val label: String, val trailing: String?)

private data class ClockRotLabels(val portrait: String, val landscape: String, val auto: String)
private data class OnOffLabels(val on: String, val off: String)

private fun menuRows(ctx: android.content.Context): List<DisplayRow> =
    DeviceMenuState.MENU_ITEMS.map { DisplayRow(DeviceMenuState.menuItemLabel(ctx, it), null) }

private fun settingsRows(
    ctx: android.content.Context,
    state: DeviceMenuState,
    clockRot: ClockRotLabels,
    onOff: OnOffLabels,
): List<DisplayRow> =
    DeviceMenuState.SETTINGS_ITEMS.map { id ->
        DisplayRow(
            DeviceMenuState.settingsItemLabel(ctx, id),
            settingsTrailing(id, state, clockRot, onOff),
        )
    }

private fun resetRows(ctx: android.content.Context): List<DisplayRow> =
    DeviceMenuState.RESET_ITEMS.map { id ->
        DisplayRow(
            label = DeviceMenuState.resetItemLabel(ctx, id),
            trailing = if (id == "confirm") "!" else null,
        )
    }

private fun settingsTrailing(
    id: String,
    state: DeviceMenuState,
    clockRot: ClockRotLabels,
    onOff: OnOffLabels,
): String? = when (id) {
    "brightness" -> "${state.brightness}/4"
    "sound" -> boolLabel(state.sound, onOff)
    "bluetooth" -> boolLabel(state.bt, onOff)
    "wifi" -> boolLabel(state.wifi, onOff)
    "led" -> boolLabel(state.led, onOff)
    "transcript" -> boolLabel(state.hud, onOff)
    "clock rot" -> when (state.clockRot) {
        1 -> clockRot.portrait
        2 -> clockRot.landscape
        else -> clockRot.auto
    }
    "ascii pet" -> ">"
    "reset" -> ">"
    "back" -> "<"
    else -> null
}

private fun boolLabel(v: Boolean, labels: OnOffLabels): String = if (v) labels.on else labels.off

@Composable
private fun SectionList(
    titleLabel: String,
    rows: List<DisplayRow>,
    selected: Int,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = titleLabel,
            color = TerminalPalette.accentSoft,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 2.sp),
        )
        rows.forEachIndexed { idx, row ->
            RowView(row = row, isSelected = idx == selected)
        }
    }
}

@Composable
private fun RowView(row: DisplayRow, isSelected: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = if (isSelected) ">" else " ",
            color = if (isSelected) TerminalPalette.accent else TerminalPalette.inkDim,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Row(
            modifier = Modifier
                .weight(1f)
                .background(
                    if (isSelected) TerminalPalette.ink else Color.Transparent,
                    RoundedCornerShape(4.dp),
                )
                .padding(horizontal = 8.dp, vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = row.label,
                color = if (isSelected) TerminalPalette.lcdBg else TerminalPalette.ink,
                fontSize = 13.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                style = TextStyle(fontFamily = TerminalFonts.mono),
                modifier = Modifier.weight(1f),
            )
            if (row.trailing != null) {
                Text(
                    text = row.trailing,
                    color = if (isSelected) TerminalPalette.lcdBg else TerminalPalette.inkDim,
                    fontSize = 13.sp,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                    style = TextStyle(fontFamily = TerminalFonts.mono),
                )
            }
        }
    }
}

@Composable
private fun Footer() {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FooterHint(stringResource(R.string.device_menu_hint_a_long), stringResource(R.string.device_menu_hint_close))
            FooterHint(stringResource(R.string.device_menu_hint_a_short), stringResource(R.string.device_menu_hint_next))
            FooterHint(stringResource(R.string.device_menu_hint_b_short), stringResource(R.string.device_menu_hint_apply))
        }
        Text(
            text = stringResource(R.string.device_menu_notice_demo_only),
            color = TerminalPalette.inkDim,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun FooterHint(key: String, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = key,
            color = TerminalPalette.accentSoft,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = value,
            color = TerminalPalette.inkDim,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

/**
 * Opaque screen-off mask. A short tap anywhere wakes the screen — the
 * handheld buttons are covered by this mask when screenOff is true, so the
 * user needs an unambiguous wake gesture.
 */
@Composable
fun ScreenOffMask(onWake: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
            .clickable(onClick = onWake),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = stringResource(R.string.device_menu_screen_off),
            color = TerminalPalette.inkDim.copy(alpha = 0.35f),
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}
