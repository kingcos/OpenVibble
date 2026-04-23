// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.nusperipheral.NusConnectionState
import com.openvibble.persona.PersonaController
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette
import kotlinx.coroutines.delay

/**
 * Android parity with iOS `InfoBody`. Six paged reference cards — ABOUT,
 * BUTTONS, CLAUDE, DEVICE, BLE, CREDITS. CLAUDE delegates to
 * `ClaudeSessionsView` so the chip-row + detail pane matches iOS 1:1.
 *
 * DEVICE page reads battery via sticky ACTION_BATTERY_CHANGED broadcast
 * (same intent BridgeAppModel's battery receiver consumes).
 */
internal val INFO_PAGES: List<String> = listOf(
    "ABOUT", "BUTTONS", "CLAUDE", "DEVICE", "BLE", "CREDITS",
)

@Composable
internal fun InfoBody(
    model: BridgeAppModel,
    persona: PersonaController,
    page: Int,
    appStartMs: Long,
    modifier: Modifier = Modifier,
) {
    val title = INFO_PAGES[page]
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = "INFO",
                color = TerminalPalette.ink,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
                style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "${page + 1}/${INFO_PAGES.size}",
                color = TerminalPalette.inkDim,
                fontSize = 11.sp,
                style = TextStyle(fontFamily = TerminalFonts.mono),
            )
        }
        Text(
            text = titleLabel(title),
            color = TerminalPalette.accentSoft,
            fontSize = 15.sp,
            fontWeight = FontWeight.ExtraBold,
            style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(TerminalPalette.lcdDivider),
        )

        when (title) {
            "CLAUDE" -> ClaudeSessionsView(model = model, persona = persona)
            else -> TextRows(rows = rowsFor(title, model = model, appStartMs = appStartMs))
        }
    }
}

private sealed class InfoRow {
    data class Body(val text: String) : InfoRow()
    data class Pair(val label: String, val value: String) : InfoRow()
}

@Composable
private fun TextRows(rows: List<InfoRow>) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        rows.forEach { row ->
            when (row) {
                is InfoRow.Body -> Text(
                    text = row.text,
                    color = TerminalPalette.ink,
                    fontSize = 12.sp,
                    style = TextStyle(fontFamily = TerminalFonts.mono),
                    modifier = Modifier.fillMaxWidth(),
                )
                is InfoRow.Pair -> Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Text(
                        text = row.label,
                        color = TerminalPalette.inkDim,
                        fontSize = 12.sp,
                        style = TextStyle(fontFamily = TerminalFonts.mono),
                        modifier = Modifier.width(84.dp),
                    )
                    Text(
                        text = row.value,
                        color = TerminalPalette.ink,
                        fontSize = 12.sp,
                        style = TextStyle(fontFamily = TerminalFonts.mono),
                    )
                }
            }
        }
    }
}

private fun titleLabel(title: String): String = when (title) {
    "ABOUT" -> "关于 OpenVibble"
    "BUTTONS" -> "硬件按键说明"
    "CLAUDE" -> "Claude 会话快览"
    "DEVICE" -> "设备状态"
    "BLE" -> "BLE 外设状态"
    "CREDITS" -> "致谢"
    else -> title
}

@Composable
private fun rowsFor(title: String, model: BridgeAppModel, appStartMs: Long): List<InfoRow> {
    val context = LocalContext.current
    return when (title) {
        "ABOUT" -> listOf(
            InfoRow.Body("OpenVibble 是 Claude Desktop Buddy 硬件桌搭的陪伴 App。"),
            InfoRow.Body("顶部显示 BLE 状态，中部显示像素宠物，底部 A/B 模拟实体按键。"),
            InfoRow.Body("收到 Claude Desktop 的权限请求后，A=允许 / B=拒绝。"),
            InfoRow.Body("源码 MPL-2.0，详见 GitHub。"),
        )
        "BUTTONS" -> listOf(
            InfoRow.Body("A · 短按：NORMAL → PET → INFO 循环。"),
            InfoRow.Body("A · 短按 · NORMAL 有 prompt：允许一次。"),
            InfoRow.Body("A · 长按：开关设备菜单（亮度/声音/重置）。"),
            InfoRow.Body("B · 短按 · NORMAL 有 prompt：拒绝。"),
            InfoRow.Body("B · 短按 · PET/INFO：翻页。左右滑动亦可。"),
        )
        "DEVICE" -> {
            val battery = readBatteryLabel(context)
            val charging = readChargingLabel(context)
            val uptime = rememberUptimeLabel(appStartMs)
            listOf(
                InfoRow.Pair("battery", battery),
                InfoRow.Pair("usb", charging),
                InfoRow.Pair("uptime", uptime),
                InfoRow.Pair("pet", "Buddy"),
            )
        }
        "BLE" -> {
            val conn by model.connectionState.collectAsState()
            val adv by model.advertisingNote.collectAsState()
            val name by model.activeDisplayName.collectAsState()
            listOf(
                InfoRow.Pair("link", linkLabel(conn)),
                InfoRow.Pair("adv", adv),
                InfoRow.Pair("name", name),
                InfoRow.Pair("uuid", "6e400001-...e9d6"),
            )
        }
        "CREDITS" -> listOf(
            InfoRow.Body("Claude 是 Anthropic 的产品，本项目与其无从属关系。"),
            InfoRow.Body("ASCII 字符源于 @Kenney 的 ASCII pet kit 再创作。"),
            InfoRow.Body("感谢所有在 issue 区留过反馈的朋友。"),
        )
        else -> emptyList()
    }
}

@Composable
private fun rememberUptimeLabel(appStartMs: Long): String {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = System.currentTimeMillis()
            delay(1_000L)
        }
    }
    return formatUptime(((now - appStartMs) / 1000L).toInt().coerceAtLeast(0))
}

private fun linkLabel(state: NusConnectionState): String = when (state) {
    is NusConnectionState.Stopped -> "off"
    is NusConnectionState.Advertising -> "advertising"
    is NusConnectionState.Connected -> "connected(${state.centralCount})"
}

private fun readBatteryLabel(context: Context): String {
    val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return "—"
    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
    val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
    if (level < 0 || scale <= 0) return "—"
    val pct = ((level.toFloat() / scale.toFloat()) * 100f).toInt()
    return "${pct}%"
}

private fun readChargingLabel(context: Context): String {
    val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) ?: return "off"
    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
    return if (charging) "on" else "off"
}

private fun formatUptime(seconds: Int): String {
    val h = seconds / 3600
    val m = (seconds / 60) % 60
    val s = seconds % 60
    return when {
        h > 0 -> "%dh%02dm".format(h, m)
        m > 0 -> "%dm%02ds".format(m, s)
        else -> "${s}s"
    }
}
