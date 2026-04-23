// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize(),
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
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
            when {
                state.resetOpen -> SectionList(
                    titleLabel = "RESET",
                    rows = resetRows(),
                    selected = state.resetIndex,
                )
                state.settingsOpen -> SectionList(
                    titleLabel = "SETTINGS",
                    rows = settingsRows(state),
                    selected = state.settingsIndex,
                )
                state.menuOpen -> SectionList(
                    titleLabel = "MENU",
                    rows = menuRows(),
                    selected = state.menuIndex,
                )
            }
            Spacer(Modifier.weight(1f))
            Footer()
        }
        // Transparent reserve so the handheld bar stays tappable.
        Spacer(Modifier.height(bottomReservedHeight))
    }
}

@Composable
private fun Header(state: DeviceMenuState) {
    val crumb = when {
        state.resetOpen -> "RESET"
        state.settingsOpen -> "SETTINGS"
        else -> "MENU"
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = "设备菜单",
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

private fun menuRows(): List<DisplayRow> =
    DeviceMenuState.MENU_ITEMS.map { DisplayRow(DeviceMenuState.menuItemLabel(it), null) }

private fun settingsRows(state: DeviceMenuState): List<DisplayRow> =
    DeviceMenuState.SETTINGS_ITEMS.map { id ->
        DisplayRow(DeviceMenuState.settingsItemLabel(id), settingsTrailing(id, state))
    }

private fun resetRows(): List<DisplayRow> =
    DeviceMenuState.RESET_ITEMS.map { id ->
        DisplayRow(
            label = DeviceMenuState.resetItemLabel(id),
            trailing = if (id == "confirm") "⚠" else null,
        )
    }

private fun settingsTrailing(id: String, state: DeviceMenuState): String? = when (id) {
    "brightness" -> "${state.brightness}/4"
    "sound" -> onOff(state.sound)
    "bluetooth" -> onOff(state.bt)
    "wifi" -> onOff(state.wifi)
    "led" -> onOff(state.led)
    "transcript" -> onOff(state.hud)
    "clock rot" -> when (state.clockRot) {
        1 -> "竖屏"
        2 -> "横屏"
        else -> "自动"
    }
    "ascii pet" -> "▸"
    "reset" -> "▸"
    "back" -> "◂"
    else -> null
}

private fun onOff(v: Boolean): String = if (v) "开" else "关"

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
            text = if (isSelected) "▶" else " ",
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
            FooterHint("A长按", "关闭")
            FooterHint("A短按", "下一项")
            FooterHint("B短按", "应用")
        }
        Text(
            text = "本菜单仅演示本机设置，不影响 BLE",
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
            text = "屏幕已关闭 · 点击唤醒",
            color = TerminalPalette.inkDim.copy(alpha = 0.35f),
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}
