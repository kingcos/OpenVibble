// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette
import kotlinx.coroutines.delay

/**
 * Android parity with iOS `HomeLogSheet`. A modal-like panel that surfaces
 * two log tabs — RUN (heartbeat entries + last-turn preview) and BLE
 * (peripheral connect/send/receive + diagnostic log). Copy/clear actions
 * live in the tab header.
 *
 * Not backed by a ModalBottomSheet on the Android side to keep the sheet
 * zero-Material-extras. The caller overlays it in-place with Surface.
 */
@Composable
fun HomeLogSheet(
    model: BridgeAppModel,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    var tab by remember { mutableStateOf(LogTab.RUN) }
    var copied by remember { mutableStateOf(false) }

    val snapshot by model.snapshot.collectAsState()
    val parsedEntries by model.parsedEntries.collectAsState()
    val recentEvents by model.recentEvents.collectAsState()
    val diagnostics by model.diagnosticLogs.collectAsState()

    val currentLog: List<String> = remember(tab, snapshot, parsedEntries, recentEvents, diagnostics) {
        when (tab) {
            LogTab.RUN -> buildList {
                if (snapshot.lastTurnPreview.isNotEmpty()) {
                    add("[turn:${snapshot.lastTurnRole}] ${snapshot.lastTurnPreview}")
                }
                addAll(parsedEntries)
            }
            LogTab.BLE -> buildList {
                addAll(recentEvents.take(80))
                if (diagnostics.isNotEmpty()) {
                    add("— diagnostics —")
                    addAll(diagnostics)
                }
            }
        }
    }

    LaunchedEffect(copied) {
        if (copied) {
            delay(2_000L)
            copied = false
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(TerminalPalette.lcdBg),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(top = 12.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            LogTab.values().forEach { t ->
                TabChip(
                    label = t.label,
                    count = when (t) {
                        LogTab.RUN -> (if (snapshot.lastTurnPreview.isNotEmpty()) 1 else 0) + parsedEntries.size
                        LogTab.BLE -> recentEvents.size + diagnostics.size
                    },
                    selected = tab == t,
                    onClick = { tab = t },
                )
            }
            Spacer(Modifier.weight(1f))
            IconChip(
                label = if (copied) "OK" else "COPY",
                tint = if (copied) TerminalPalette.good else TerminalPalette.ink,
                onClick = {
                    val text = currentLog.joinToString("\n")
                    if (text.isNotEmpty()) {
                        copyToClipboard(context, text)
                        copied = true
                    }
                },
            )
            IconChip(
                label = "DEL",
                tint = TerminalPalette.bad,
                enabled = currentLog.isNotEmpty(),
                onClick = { model.clearLogs() },
            )
            IconChip(
                label = "X",
                tint = TerminalPalette.inkDim,
                onClick = onDismiss,
            )
        }

        if (currentLog.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    text = "· no log ·",
                    color = TerminalPalette.inkDim,
                    fontSize = 11.sp,
                    style = TextStyle(fontFamily = TerminalFonts.mono),
                )
            }
        } else {
            val scroll = rememberScrollState()
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scroll)
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                currentLog.forEach { line ->
                    Text(
                        text = line,
                        color = TerminalPalette.ink.copy(alpha = 0.92f),
                        fontSize = 11.sp,
                        style = TextStyle(fontFamily = TerminalFonts.mono),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

enum class LogTab(val label: String) {
    RUN("RUN"), BLE("BLE")
}

@Composable
private fun TabChip(label: String, count: Int, selected: Boolean, onClick: () -> Unit) {
    val bg = if (selected) TerminalPalette.ink else TerminalPalette.lcdPanel.copy(alpha = 0.6f)
    val fg = if (selected) TerminalPalette.lcdBg else TerminalPalette.ink
    val countFg = if (selected) TerminalPalette.lcdBg.copy(alpha = 0.6f) else TerminalPalette.inkDim
    Row(
        modifier = Modifier
            .background(bg, RoundedCornerShape(20.dp))
            .border(1.dp, TerminalPalette.inkDim.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Text(
            text = label,
            color = fg,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
        )
        Text(
            text = count.toString(),
            color = countFg,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun IconChip(
    label: String,
    tint: Color,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(width = 40.dp, height = 26.dp)
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.6f), RoundedCornerShape(14.dp))
            .border(1.dp, TerminalPalette.inkDim.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
            .alpha(if (enabled) 1f else 0.4f)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = tint,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
        )
    }
}

private fun copyToClipboard(context: Context, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    clipboard?.setPrimaryClip(ClipData.newPlainText("openvibble.log", text))
}
