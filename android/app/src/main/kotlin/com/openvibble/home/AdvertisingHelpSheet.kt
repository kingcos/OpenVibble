// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.ui.terminal.TerminalActionButton
import com.openvibble.ui.terminal.TerminalActionButtonRole
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette

/**
 * Android parity with iOS `AdvertisingHelpSheet`, trimmed for Android: show
 * the Desktop bridge pointer plus a reconnect tip, and let Back close it.
 */
private const val DESKTOP_RELEASES_URL = "https://github.com/kingcos/OpenVibble/releases"

@Composable
fun AdvertisingHelpSheet(
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current

    BackHandler(onBack = onDismiss)

    Column(
        modifier = modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
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
            TerminalActionButton(
                label = stringResource(R.string.common_close),
                onClick = onDismiss,
            )
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
        TerminalActionButton(
            leading = "GET",
            label = stringResource(R.string.home_help_claude_code_link),
            role = TerminalActionButtonRole.Primary,
            fill = true,
            onClick = onOpenLink,
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

private fun openUrl(context: Context, url: String) {
    runCatching {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
