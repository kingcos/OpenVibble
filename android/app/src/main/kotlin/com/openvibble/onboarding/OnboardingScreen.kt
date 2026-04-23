// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.onboarding

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.openvibble.R
import com.openvibble.ui.terminal.ButtonCheatSheet
import com.openvibble.ui.terminal.CheatBadge
import com.openvibble.ui.terminal.CheatRow
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette

/**
 * Android parity with iOS `OnboardingScreen`. Two stacked step cards the user
 * walks through top-to-bottom:
 *   1. Grant BLE + notification permission (explicit tap — no auto-prompt)
 *   2. Skim the button cheat-sheet
 *
 * Unlike iOS (single `CBManager` authorization), Android needs runtime
 * permission requests for multiple strings depending on API level; the
 * [BluetoothPermissions] helper centralises that.
 */
@Composable
fun OnboardingScreen(onFinish: () -> Unit) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    // Whether the user has tapped "grant" — lets us distinguish first-run
    // (NOT_DETERMINED) from a real denial.
    var bleRequested by remember { mutableStateOf(false) }
    var notifRequested by remember { mutableStateOf(false) }

    // Re-read permission state whenever the user returns from Settings.
    var bleGranted by remember { mutableStateOf(BluetoothPermissions.allGranted(context)) }
    var notifGranted by remember { mutableStateOf(BluetoothPermissions.notificationsGranted(context)) }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                bleGranted = BluetoothPermissions.allGranted(context)
                notifGranted = BluetoothPermissions.notificationsGranted(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val bleLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { results ->
        bleGranted = results.values.all { it }
    }
    val notifLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> notifGranted = granted }

    val bleStatus = when {
        bleGranted -> PermissionGroupStatus.GRANTED
        bleRequested -> PermissionGroupStatus.DENIED
        else -> PermissionGroupStatus.NOT_DETERMINED
    }
    val notifStatus = when {
        notifGranted -> PermissionGroupStatus.GRANTED
        notifRequested -> PermissionGroupStatus.DENIED
        else -> PermissionGroupStatus.NOT_DETERMINED
    }
    val permissionStepComplete = bleStatus == PermissionGroupStatus.GRANTED ||
        bleStatus == PermissionGroupStatus.DENIED

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(TerminalPalette.lcdBg),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(top = 24.dp, bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            OnboardingHeader()

            OnboardingStepCard(
                index = 1,
                title = stringResource(R.string.onboarding_step_permission_title),
                subtitle = stringResource(R.string.onboarding_step_permission_body),
                active = !permissionStepComplete,
                done = permissionStepComplete,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    PermissionRow(
                        label = stringResource(R.string.onboarding_permission_ble),
                        status = bleStatus,
                    ) {
                        bleRequested = true
                        if (bleStatus == PermissionGroupStatus.DENIED) {
                            openAppSettings(context)
                        } else {
                            bleLauncher.launch(BluetoothPermissions.required())
                        }
                    }
                    PermissionRow(
                        label = stringResource(R.string.onboarding_permission_notification),
                        status = notifStatus,
                    ) {
                        notifRequested = true
                        if (notifStatus == PermissionGroupStatus.DENIED) {
                            openAppSettings(context)
                        } else {
                            val perm = BluetoothPermissions.notification()
                            if (perm != null) notifLauncher.launch(perm)
                            else notifGranted = true
                        }
                    }
                }
            }

            OnboardingStepCard(
                index = 2,
                title = stringResource(R.string.onboarding_step_help_title),
                subtitle = stringResource(R.string.onboarding_step_help_body),
                active = permissionStepComplete,
                done = false,
            ) {
                ButtonCheatSheet(rows = defaultCheatRows())
            }
        }

        FooterCta(
            modifier = Modifier.align(Alignment.BottomCenter),
            enabled = permissionStepComplete,
            onEnter = onFinish,
            onSkip = onFinish,
        )
    }
}

@Composable
private fun OnboardingHeader() {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = stringResource(R.string.onboarding_prompt),
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
        )
        Text(
            text = stringResource(R.string.onboarding_welcome_title),
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.display,
            fontWeight = FontWeight.ExtraBold,
            fontSize = 32.sp,
            letterSpacing = 2.sp,
        )
        Text(
            text = stringResource(R.string.onboarding_welcome_body),
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
            lineHeight = 18.sp,
        )
    }
}

@Composable
private fun OnboardingStepCard(
    index: Int,
    title: String,
    subtitle: String,
    active: Boolean,
    done: Boolean,
    content: @Composable () -> Unit,
) {
    val badgeBg = when {
        done -> TerminalPalette.good
        active -> TerminalPalette.accent
        else -> TerminalPalette.lcdPanel
    }
    val cardBg = if (active) TerminalPalette.lcdPanel.copy(alpha = 0.9f)
        else TerminalPalette.lcdPanel.copy(alpha = 0.45f)
    val stroke = when {
        done -> TerminalPalette.good.copy(alpha = 0.6f)
        active -> TerminalPalette.accent.copy(alpha = 0.8f)
        else -> TerminalPalette.inkDim.copy(alpha = 0.35f)
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(cardBg, RoundedCornerShape(12.dp))
            .border(BorderStroke(if (active) 1.5.dp else 1.dp, stroke), RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .background(badgeBg, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                if (done) {
                    Text(
                        text = "✓",
                        color = TerminalPalette.lcdBg,
                        fontFamily = TerminalFonts.mono,
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                    )
                } else {
                    Text(
                        text = index.toString(),
                        color = if (active) Color.White else TerminalPalette.inkDim,
                        fontFamily = TerminalFonts.mono,
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                    )
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = title,
                    color = TerminalPalette.ink,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                )
                Text(
                    text = subtitle,
                    color = TerminalPalette.inkDim,
                    fontFamily = TerminalFonts.mono,
                    fontSize = 11.sp,
                    lineHeight = 16.sp,
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 38.dp)
                .alpha(if (active || done) 1f else 0.45f),
        ) { content() }
    }
}

@Composable
private fun PermissionRow(
    label: String,
    status: PermissionGroupStatus,
    onAction: () -> Unit,
) {
    val color = when (status) {
        PermissionGroupStatus.GRANTED -> TerminalPalette.good
        PermissionGroupStatus.NOT_DETERMINED -> TerminalPalette.accentSoft
        PermissionGroupStatus.DENIED -> TerminalPalette.bad
    }
    val statusRes = when (status) {
        PermissionGroupStatus.GRANTED -> R.string.onboarding_permission_status_allowed
        PermissionGroupStatus.NOT_DETERMINED -> R.string.onboarding_permission_status_not_determined
        PermissionGroupStatus.DENIED -> R.string.onboarding_permission_status_denied
    }
    val actionRes = when (status) {
        PermissionGroupStatus.GRANTED -> R.string.onboarding_permission_granted
        PermissionGroupStatus.DENIED -> R.string.onboarding_permission_open_settings
        PermissionGroupStatus.NOT_DETERMINED -> R.string.onboarding_permission_request
    }
    val actionDisabled = status == PermissionGroupStatus.GRANTED

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(modifier = Modifier.size(7.dp).background(color, CircleShape))
            WeightText(
                text = label,
                color = TerminalPalette.ink,
                weight = 1f,
                bold = true,
                size = 12,
            )
            Text(
                text = stringResource(statusRes),
                color = color,
                fontFamily = TerminalFonts.mono,
                fontSize = 11.sp,
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    if (actionDisabled) TerminalPalette.lcdPanel else TerminalPalette.accent,
                    RoundedCornerShape(8.dp),
                )
                .border(
                    BorderStroke(1.dp, Color.Black.copy(alpha = 0.3f)),
                    RoundedCornerShape(8.dp),
                )
                .clickable(enabled = !actionDisabled, onClick = onAction)
                .padding(vertical = 9.dp, horizontal = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(actionRes),
                color = if (actionDisabled) TerminalPalette.inkDim else Color.White,
                fontFamily = TerminalFonts.mono,
                fontWeight = FontWeight.SemiBold,
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
private fun RowScope.WeightText(
    text: String,
    color: Color,
    weight: Float,
    bold: Boolean,
    size: Int,
) {
    Text(
        text = text,
        color = color,
        fontFamily = TerminalFonts.mono,
        fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal,
        fontSize = size.sp,
        modifier = Modifier.weight(weight, fill = true),
    )
}

@Composable
private fun FooterCta(
    modifier: Modifier = Modifier,
    enabled: Boolean,
    onEnter: () -> Unit,
    onSkip: () -> Unit,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .background(
                    Brush.verticalGradient(colors = listOf(Color.Transparent, TerminalPalette.lcdBg)),
                ),
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(TerminalPalette.lcdBg)
                .padding(horizontal = 20.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        if (enabled) TerminalPalette.accent else TerminalPalette.lcdPanel,
                        RoundedCornerShape(12.dp),
                    )
                    .border(
                        BorderStroke(
                            1.dp,
                            if (enabled) TerminalPalette.shellBottom.copy(alpha = 0.7f)
                            else TerminalPalette.inkDim.copy(alpha = 0.4f),
                        ),
                        RoundedCornerShape(12.dp),
                    )
                    .clickable(enabled = enabled, onClick = onEnter)
                    .padding(vertical = 14.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(
                        if (enabled) R.string.onboarding_cta_enter
                        else R.string.onboarding_cta_needs_permission,
                    ),
                    color = if (enabled) Color.White else TerminalPalette.inkDim,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
            }
            Box(
                modifier = Modifier.clickable(onClick = onSkip).padding(vertical = 4.dp),
            ) {
                Text(
                    text = stringResource(R.string.onboarding_cta_skip),
                    color = TerminalPalette.inkDim,
                    fontFamily = TerminalFonts.mono,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 11.sp,
                )
            }
        }
    }
}

private fun defaultCheatRows(): List<CheatRow> = listOf(
    CheatRow(CheatBadge.Text("A"), "按 A 键在主页切换 Claude/Info 面板"),
    CheatRow(CheatBadge.LongPress("A"), "长按 A · 快速触发一次权限回复"),
    CheatRow(CheatBadge.Text("B"), "按 B 键返回或关闭当前菜单"),
    CheatRow(CheatBadge.Icon("⏻"), "按电源键翻转睡眠"),
    CheatRow(CheatBadge.Icon("≡"), "按日志键查看最近事件"),
    CheatRow(CheatBadge.Icon("⚙"), "按齿轮键进入设置"),
)

private fun openAppSettings(context: Context) {
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", context.packageName, null)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }
    context.startActivity(intent)
}
