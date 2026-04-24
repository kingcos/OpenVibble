// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette
import kotlinx.coroutines.delay

/**
 * Android parity with iOS `AdvertisingHelpSheet`. Three cards stacked
 * vertically — Claude Code install pointer, Bluetooth rename hint with a
 * `claude.xxxxx` suggestion, and a reconnect tip.
 *
 * The iOS sheet steers users toward "设置 → 通用 → 关于本机 → 名称" because
 * iOS derives the LE advertisement name from the system device name. Android
 * lets us set the advertised name directly from `AdvertiseData.setIncludeDeviceName`
 * via `adapter.name`, so the rename-flow is mostly a safety net for devices
 * where the OEM blocks programmatic renaming — we hand the user a known-good
 * claude.xxxxx suggestion and deep-link into the system Bluetooth settings.
 */
private const val DESKTOP_RELEASES_URL = "https://github.com/kingcos/OpenVibble/releases"

@Composable
fun AdvertisingHelpSheet(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    var suggestedName by remember { mutableStateOf(makeSuggestedName()) }
    var copied by remember { mutableStateOf(false) }

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
            Text(
                text = stringResource(R.string.home_help_title),
                color = TerminalPalette.ink,
                fontSize = 18.sp,
                fontWeight = FontWeight.ExtraBold,
                style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
            )
            Spacer(Modifier.weight(1f))
            CloseChip(onClick = onDismiss)
        }

        val scroll = rememberScrollState()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scroll)
                .padding(horizontal = 20.dp)
                .padding(top = 8.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Header()
            ClaudeCodeSection(onOpenLink = { openUrl(context, DESKTOP_RELEASES_URL) })
            RenameSection(
                suggestedName = suggestedName,
                copied = copied,
                onShuffle = { suggestedName = makeSuggestedName() },
                onCopy = {
                    copyToClipboard(context, suggestedName)
                    copied = true
                },
                onOpenSettings = {
                    copyToClipboard(context, suggestedName)
                    copied = true
                    openBluetoothSettings(context)
                },
            )
            ReconnectHint()
        }
    }
}

@Composable
private fun Header() {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = "$ openvibble --help",
            color = TerminalPalette.inkDim,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = stringResource(R.string.home_help_title),
            color = TerminalPalette.ink,
            fontSize = 28.sp,
            fontWeight = FontWeight.ExtraBold,
            style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
        )
    }
}

@Composable
private fun ClaudeCodeSection(onOpenLink: () -> Unit) {
    HelpCard(title = stringResource(R.string.home_help_claude_code_title)) {
        Text(
            text = stringResource(R.string.home_help_claude_code_body),
            color = TerminalPalette.ink,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        PrimaryButton(
            leading = "GET",
            text = stringResource(R.string.home_help_claude_code_link),
            trailing = null,
            onClick = onOpenLink,
        )
    }
}

@Composable
private fun RenameSection(
    suggestedName: String,
    copied: Boolean,
    onShuffle: () -> Unit,
    onCopy: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    HelpCard(title = stringResource(R.string.home_help_rename_title)) {
        Text(
            text = stringResource(R.string.home_help_rename_body),
            color = TerminalPalette.ink,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        NameRow(
            name = suggestedName,
            copied = copied,
            onShuffle = onShuffle,
            onCopy = onCopy,
        )
        PrimaryButton(
            leading = "BT",
            text = stringResource(R.string.home_help_rename_open_settings),
            trailing = null,
            onClick = onOpenSettings,
        )
        InfoHint(
            text = stringResource(R.string.home_help_rename_manual_hint),
        )
    }
}

@Composable
private fun ReconnectHint() {
    Text(
        text = stringResource(R.string.settings_help_reconnect_hint),
        color = TerminalPalette.bad,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        style = TextStyle(fontFamily = TerminalFonts.mono),
        modifier = Modifier
            .fillMaxWidth()
            .background(
                TerminalPalette.lcdPanel.copy(alpha = 0.6f),
                RoundedCornerShape(10.dp),
            )
            .border(
                1.dp,
                TerminalPalette.bad.copy(alpha = 0.5f),
                RoundedCornerShape(10.dp),
            )
            .padding(12.dp),
    )
}

@Composable
private fun HelpCard(title: String, body: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                TerminalPalette.lcdPanel.copy(alpha = 0.85f),
                RoundedCornerShape(12.dp),
            )
            .border(
                1.dp,
                TerminalPalette.inkDim.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp),
            )
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = title,
            color = TerminalPalette.ink,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        body()
    }
}

@Composable
private fun NameRow(
    name: String,
    copied: Boolean,
    onShuffle: () -> Unit,
    onCopy: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                TerminalPalette.lcdPanel.copy(alpha = 0.7f),
                RoundedCornerShape(8.dp),
            )
            .border(
                1.dp,
                TerminalPalette.inkDim.copy(alpha = 0.5f),
                RoundedCornerShape(8.dp),
            )
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = name,
            color = TerminalPalette.ink,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        HeaderButton(
            label = "NEW",
            fill = false,
            onClick = onShuffle,
        )
        HeaderButton(
            label = if (copied) {
                "OK ${stringResource(R.string.common_copied)}"
            } else {
                stringResource(R.string.common_copy)
            },
            fill = false,
            onClick = onCopy,
        )
    }
}

@Composable
private fun HeaderButton(
    label: String,
    fill: Boolean,
    onClick: () -> Unit,
) {
    val bg = if (fill) TerminalPalette.accent.copy(alpha = 0.85f) else TerminalPalette.lcdPanel.copy(alpha = 0.6f)
    val fg = if (fill) Color.White else TerminalPalette.ink
    Box(
        modifier = Modifier
            .background(bg, RoundedCornerShape(8.dp))
            .border(
                1.dp,
                if (fill) Color.Black.copy(alpha = 0.3f) else TerminalPalette.inkDim.copy(alpha = 0.45f),
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = fg,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun PrimaryButton(
    leading: String,
    text: String,
    trailing: String?,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                TerminalPalette.accent.copy(alpha = 0.85f),
                RoundedCornerShape(8.dp),
            )
            .border(
                1.dp,
                Color.Black.copy(alpha = 0.3f),
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = leading,
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = text,
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.weight(1f),
        )
        if (trailing != null) {
            Text(
                text = trailing,
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                style = TextStyle(fontFamily = TerminalFonts.mono),
            )
        }
    }
}

@Composable
private fun InfoHint(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                TerminalPalette.lcdPanel.copy(alpha = 0.5f),
                RoundedCornerShape(8.dp),
            )
            .padding(10.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "i",
            color = TerminalPalette.accentSoft,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = text,
            color = TerminalPalette.inkDim,
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun CloseChip(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(width = 40.dp, height = 26.dp)
            .background(
                TerminalPalette.lcdPanel.copy(alpha = 0.6f),
                RoundedCornerShape(14.dp),
            )
            .border(
                1.dp,
                TerminalPalette.inkDim.copy(alpha = 0.45f),
                RoundedCornerShape(14.dp),
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "X",
            color = TerminalPalette.inkDim,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

/** `claude.xxxxx` — 5 hex chars keep the name under Android's 29-byte scan-response cap. */
internal fun makeSuggestedName(): String {
    val chars = "0123456789abcdef"
    val suffix = (0 until 5).map { chars.random() }.joinToString("")
    return "claude.$suffix"
}

private fun copyToClipboard(context: Context, text: String) {
    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    cm.setPrimaryClip(ClipData.newPlainText("advertise-name", text))
}

private fun openUrl(context: Context, url: String) {
    runCatching {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}

private fun openBluetoothSettings(context: Context) {
    runCatching {
        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }.onFailure {
        runCatching {
            val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(fallback)
        }
    }
}
