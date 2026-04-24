// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.settings

import android.content.Intent
import android.os.Build
import android.net.Uri
import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.persona.PersonaCatalog
import com.openvibble.persona.PersonaSelection
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.stats.PersonaStatsStore
import com.openvibble.ui.terminal.ButtonCheatSheet
import com.openvibble.ui.terminal.CheatBadge
import com.openvibble.ui.terminal.CheatRow
import com.openvibble.ui.terminal.TerminalBackground
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalHeaderButton
import com.openvibble.ui.terminal.TerminalPalette
import com.openvibble.ui.terminal.TerminalPanel
import com.openvibble.ui.terminal.TerminalThemeMode
import java.util.Locale

/**
 * Android parity with iOS `SettingsScreen`. Six stacked terminal panels (pet,
 * interface, alerts, about, guide, danger). LiveActivity is iOS-only and
 * intentionally omitted from alerts.
 */
@Composable
fun SettingsScreen(
    model: BridgeAppModel,
    settings: AppSettings,
    terminalTheme: TerminalThemeMode,
    onTerminalThemeChange: (TerminalThemeMode) -> Unit,
    onDone: () -> Unit,
    onRequestNotificationPermission: () -> Unit,
    onShowOnboarding: () -> Unit,
    onPickSpecies: () -> Unit,
) {
    val context = LocalContext.current
    val stats: PersonaStatsStore = model.statsStore

    var notificationsEnabled by remember { mutableStateOf(settings.notificationsEnabled) }
    var foregroundNotificationsEnabled by remember { mutableStateOf(settings.foregroundNotificationsEnabled) }
    var showPowerButton by remember { mutableStateOf(settings.showPowerButton) }

    var confirmResetStats by remember { mutableStateOf(false) }
    var confirmDeleteChars by remember { mutableStateOf(false) }
    var infoMessage by remember { mutableStateOf<String?>(null) }
    var installedCount by remember {
        mutableStateOf(PersonaCatalog(model.charactersRoot).listInstalled().size)
    }
    val selection by remember {
        mutableStateOf(PersonaSelectionStoreFactory(context).load())
    }

    Box(modifier = Modifier.fillMaxSize()) {
        TerminalBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            HeaderBar(onDone = onDone)

            TerminalPanel(title = stringResource(R.string.settings_section_pet)) {
                SpeciesRow(label = speciesLabel(selection), onClick = onPickSpecies)
            }

            TerminalPanel(title = stringResource(R.string.settings_section_interface)) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    ThemeModeRow(
                        selected = terminalTheme,
                        onSelect = onTerminalThemeChange,
                    )
                    TerminalToggleRow(
                        label = stringResource(R.string.settings_interface_show_power_button),
                        checked = showPowerButton,
                        onCheckedChange = {
                            showPowerButton = it
                            settings.showPowerButton = it
                        },
                    )
                    Text(
                        text = stringResource(R.string.settings_interface_show_power_button_hint),
                        color = TerminalPalette.inkDim,
                        fontFamily = TerminalFonts.mono,
                        fontSize = 10.sp,
                    )
                }
            }

            TerminalPanel(title = stringResource(R.string.settings_section_alerts)) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    TerminalToggleRow(
                        label = stringResource(R.string.settings_notifications_label),
                        checked = notificationsEnabled,
                        onCheckedChange = {
                            notificationsEnabled = it
                            settings.notificationsEnabled = it
                        },
                    )
                    TerminalToggleRow(
                        label = stringResource(R.string.settings_notifications_foreground_label),
                        checked = foregroundNotificationsEnabled,
                        enabled = notificationsEnabled,
                        onCheckedChange = {
                            foregroundNotificationsEnabled = it
                            settings.foregroundNotificationsEnabled = it
                        },
                    )
                    Text(
                        text = stringResource(R.string.settings_notifications_foreground_hint),
                        color = TerminalPalette.inkDim,
                        fontFamily = TerminalFonts.mono,
                        fontSize = 10.sp,
                    )
                    TerminalHeaderButton(
                        label = stringResource(R.string.settings_notifications_request),
                        fill = true,
                        onClick = onRequestNotificationPermission,
                    )
                }
            }

            TerminalPanel(title = stringResource(R.string.settings_section_about)) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    AboutRow(
                        label = stringResource(R.string.settings_about_app),
                        value = "OpenVibble",
                    )
                    AboutRow(
                        label = stringResource(R.string.settings_about_version),
                        value = appVersion(context),
                    )
                    AuthorRow()
                    AboutRow(
                        label = stringResource(R.string.settings_about_language),
                        value = currentLanguageLabel(),
                    )
                    Spacer(Modifier.height(6.dp))
                    ExternalLinkRow(
                        label = stringResource(R.string.settings_github),
                        url = "https://github.com/kingcos/OpenVibble",
                    )
                }
            }

            TerminalPanel(
                title = stringResource(R.string.settings_section_guide),
                collapsible = true,
                collapsedByDefault = true,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ButtonCheatSheet(rows = defaultCheatRows())
                    Text(
                        text = stringResource(R.string.settings_help_reconnect_hint),
                        color = TerminalPalette.bad,
                        fontFamily = TerminalFonts.mono,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                    )
                    ActionRow(
                        label = stringResource(R.string.settings_guide_show),
                        tint = TerminalPalette.ink,
                        onClick = onShowOnboarding,
                    )
                }
            }

            TerminalPanel(
                title = stringResource(R.string.settings_section_danger),
                accent = TerminalPalette.bad,
                collapsible = true,
                collapsedByDefault = true,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    ActionRow(
                        label = stringResource(R.string.pet_reset),
                        tint = TerminalPalette.bad,
                        onClick = { confirmResetStats = true },
                    )
                    ActionRow(
                        label = stringResource(R.string.pet_delete),
                        tint = if (installedCount == 0) TerminalPalette.inkDim else TerminalPalette.bad,
                        enabled = installedCount > 0,
                        onClick = { confirmDeleteChars = true },
                    )
                }
            }
        }
    }

    if (confirmResetStats) {
        ConfirmAlert(
            title = stringResource(R.string.pet_reset_confirm),
            message = stringResource(R.string.pet_reset_message),
            confirmLabel = stringResource(R.string.pet_reset_do_it),
            onConfirm = {
                stats.reset()
                settings.clearAll()
                PersonaSelectionStoreFactory(context).save(PersonaSelection.defaultSpecies)
                onTerminalThemeChange(TerminalThemeMode.EInk)
                infoMessage = context.getString(R.string.pet_stats_reset_ok)
                confirmResetStats = false
            },
            onDismiss = { confirmResetStats = false },
        )
    }
    if (confirmDeleteChars) {
        ConfirmAlert(
            title = stringResource(R.string.pet_delete_confirm),
            message = stringResource(R.string.pet_delete_message),
            confirmLabel = stringResource(R.string.pet_delete_do_it),
            onConfirm = {
                val ok = PersonaCatalog(model.charactersRoot).deleteAll()
                PersonaSelectionStoreFactory(context).save(PersonaSelection.defaultSpecies)
                installedCount = PersonaCatalog(model.charactersRoot).listInstalled().size
                infoMessage = context.getString(
                    if (ok) R.string.pet_stats_delete_ok else R.string.pet_stats_delete_fail,
                )
                confirmDeleteChars = false
            },
            onDismiss = { confirmDeleteChars = false },
        )
    }
    infoMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { infoMessage = null },
            title = { Text(stringResource(R.string.common_notice)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = { infoMessage = null }) {
                    Text(stringResource(R.string.common_ok))
                }
            },
        )
    }
}

@Composable
private fun ThemeModeRow(
    selected: TerminalThemeMode,
    onSelect: (TerminalThemeMode) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = stringResource(R.string.settings_interface_theme),
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ThemeModeButton(
                label = stringResource(R.string.settings_interface_theme_eink),
                selected = selected == TerminalThemeMode.EInk,
                onClick = { onSelect(TerminalThemeMode.EInk) },
                modifier = Modifier.weight(1f),
            )
            ThemeModeButton(
                label = stringResource(R.string.settings_interface_theme_classic),
                selected = selected == TerminalThemeMode.ClassicLcd,
                onClick = { onSelect(TerminalThemeMode.ClassicLcd) },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun ThemeModeButton(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val bg = if (selected) TerminalPalette.ink else TerminalPalette.lcdPanel.copy(alpha = 0.65f)
    val fg = if (selected) TerminalPalette.lcdBg else TerminalPalette.ink
    Row(
        modifier = modifier
            .background(bg, RoundedCornerShape(8.dp))
            .border(
                BorderStroke(1.dp, TerminalPalette.inkDim.copy(alpha = 0.55f)),
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Text(
            text = label,
            color = fg,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.SemiBold,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun HeaderBar(onDone: () -> Unit) {
    Row(verticalAlignment = Alignment.Bottom) {
        Text(
            text = "$",
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp,
        )
        Spacer(Modifier.padding(end = 6.dp))
        Text(
            text = stringResource(R.string.settings_title),
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.display,
            fontWeight = FontWeight.ExtraBold,
            fontSize = 26.sp,
            letterSpacing = 2.sp,
        )
        Spacer(Modifier.weight(1f))
        TerminalHeaderButton(
            label = stringResource(R.string.common_done),
            onClick = onDone,
        )
    }
}

@Composable
private fun SpeciesRow(label: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.7f), RoundedCornerShape(8.dp))
            .border(
                BorderStroke(1.dp, TerminalPalette.inkDim.copy(alpha = 0.5f)),
                RoundedCornerShape(8.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.settings_species),
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = label,
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
        )
        Spacer(Modifier.padding(end = 4.dp))
        Text(
            text = ">",
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.Bold,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun TerminalToggleRow(
    label: String,
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = TerminalPalette.ink.copy(alpha = if (enabled) 1f else 0.5f),
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            enabled = enabled,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = TerminalPalette.accent,
                uncheckedThumbColor = TerminalPalette.ink,
                uncheckedTrackColor = TerminalPalette.lcdPanel,
            ),
        )
    }
}

@Composable
private fun AboutRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = value,
            color = TerminalPalette.ink,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun AuthorRow() {
    val context = LocalContext.current
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = stringResource(R.string.settings_about_author),
            color = TerminalPalette.inkDim,
            fontFamily = TerminalFonts.mono,
            fontSize = 12.sp,
        )
        Spacer(Modifier.weight(1f))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.clickable {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/kingcos")))
            },
        ) {
            Text(
                text = "kingcos",
                color = TerminalPalette.ink,
                fontFamily = TerminalFonts.mono,
                fontSize = 12.sp,
                textDecoration = TextDecoration.Underline,
            )
            Spacer(Modifier.padding(end = 4.dp))
            Text(
                text = "↗",
                color = TerminalPalette.ink,
                fontFamily = TerminalFonts.mono,
                fontWeight = FontWeight.Bold,
                fontSize = 10.sp,
            )
        }
    }
}

@Composable
private fun ExternalLinkRow(label: String, url: String) {
    val context = LocalContext.current
    ActionRow(
        label = label,
        tint = TerminalPalette.ink,
        trailing = "↗",
        onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        },
    )
}

@Composable
private fun ActionRow(
    label: String,
    tint: Color,
    trailing: String = ">",
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(TerminalPalette.lcdPanel.copy(alpha = 0.6f), RoundedCornerShape(8.dp))
            .border(BorderStroke(1.dp, tint.copy(alpha = 0.4f)), RoundedCornerShape(8.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = tint,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = trailing,
            color = tint,
            fontFamily = TerminalFonts.mono,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun ConfirmAlert(
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(message) },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(confirmLabel, color = TerminalPalette.bad)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.common_cancel))
            }
        },
    )
}

@Composable
private fun defaultCheatRows(): List<CheatRow> = listOf(
    CheatRow(CheatBadge.Text("A"), stringResource(R.string.onboarding_help_a)),
    CheatRow(CheatBadge.LongPress("A"), stringResource(R.string.onboarding_help_a_long)),
    CheatRow(CheatBadge.Text("B"), stringResource(R.string.onboarding_help_b)),
    CheatRow(CheatBadge.Icon("⏻"), stringResource(R.string.onboarding_help_power)),
    CheatRow(CheatBadge.Icon("≡"), stringResource(R.string.onboarding_help_log)),
    CheatRow(CheatBadge.Icon("⚙"), stringResource(R.string.onboarding_help_gear)),
)

private fun speciesLabel(selection: PersonaSpeciesId): String = when (selection) {
    is PersonaSpeciesId.AsciiCat -> "ASCII"
    is PersonaSpeciesId.AsciiSpecies -> {
        val name = com.openvibble.persona.PersonaSpeciesCatalog.nameAt(selection.idx)
        if (name != null) "ASCII (${name.replaceFirstChar { it.titlecase(Locale.getDefault()) }})"
        else "ASCII #${selection.idx}"
    }
    is PersonaSpeciesId.Builtin -> selection.name.replaceFirstChar { it.titlecase(Locale.getDefault()) }
    is PersonaSpeciesId.Installed -> selection.name.replaceFirstChar { it.titlecase(Locale.getDefault()) }
}

private fun appVersion(context: android.content.Context): String {
    val pm = context.packageManager
    val info = pm.getPackageInfo(context.packageName, 0)
    val version = info.versionName ?: "—"
    val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        info.longVersionCode
    } else {
        @Suppress("DEPRECATION")
        info.versionCode.toLong()
    }
    return if (code > 0L) "$version ($code)" else version
}

@Composable
private fun currentLanguageLabel(): String {
    val code = Locale.getDefault().language
    return if (code.startsWith("zh")) {
        stringResource(R.string.settings_language_zh)
    } else {
        stringResource(R.string.settings_language_en)
    }
}

private fun PersonaSelectionStoreFactory(context: android.content.Context): SharedPreferencesPersonaSelectionStore =
    SharedPreferencesPersonaSelectionStore(context)
