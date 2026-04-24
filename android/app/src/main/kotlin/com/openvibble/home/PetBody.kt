// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.stats.PersonaStats
import com.openvibble.stats.PersonaStatsStore
import com.openvibble.ui.terminal.EnergyRow
import com.openvibble.ui.terminal.FedRow
import com.openvibble.ui.terminal.LevelBadge
import com.openvibble.ui.terminal.MoodRow
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette

/**
 * Android parity with iOS `PetBody` (OpenVibbleApp/Home/HomeScreen.swift).
 *
 * Two pages: `STATS` (mood/fed/energy rows + level badge + raw metrics) and
 * `HOW` (cheat-sheet mapping each indicator to how the hardware affects it).
 */
internal const val PET_PAGES: Int = 2

@Composable
internal fun PetBody(
    model: BridgeAppModel,
    stats: PersonaStatsStore,
    page: Int,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = stringResource(R.string.pet_title),
                color = TerminalPalette.ink,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
                style = TextStyle(fontFamily = TerminalFonts.display, letterSpacing = 2.sp),
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "${page + 1}/$PET_PAGES",
                color = TerminalPalette.inkDim,
                fontSize = 11.sp,
                style = TextStyle(fontFamily = TerminalFonts.mono),
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(TerminalPalette.lcdDivider),
        )
        if (page == 0) StatsPage(model = model, stats = stats) else HowPage()
    }
}

@Composable
private fun StatsPage(model: BridgeAppModel, stats: PersonaStatsStore) {
    val s by stats.stats.collectAsState()
    val snapshot by model.snapshot.collectAsState()
    val bridgeLevel = (snapshot.tokens / PersonaStats.TOKENS_PER_LEVEL.toInt()).coerceAtLeast(0)
    val displayLevel = maxOf(bridgeLevel, s.level)

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        IndicatorRow(label = stringResource(R.string.pet_metric_mood)) { MoodRow(tier = s.moodTier) }
        IndicatorRow(label = stringResource(R.string.pet_metric_fed)) { FedRow(filled = s.fedProgress) }
        IndicatorRow(label = stringResource(R.string.pet_metric_energy)) { EnergyRow(tier = stats.energyTier()) }
        LevelBadge(level = displayLevel)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            MetricRow(label = stringResource(R.string.pet_metric_approved), value = s.approvals.toString())
            MetricRow(label = stringResource(R.string.pet_metric_denied), value = s.denials.toString())
            MetricRow(label = stringResource(R.string.pet_metric_napped), value = formatNap(s.napSeconds))
            MetricRow(label = stringResource(R.string.pet_metric_tokens), value = formatTokens(snapshot.tokens.coerceAtLeast(0)))
            MetricRow(label = stringResource(R.string.pet_metric_today), value = formatTokens(snapshot.tokensToday.coerceAtLeast(0)))
        }
    }
}

@Composable
private fun IndicatorRow(label: String, indicator: @Composable () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = label,
            color = TerminalPalette.inkDim,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.width(64.dp),
        )
        indicator()
    }
}

@Composable
private fun MetricRow(label: String, value: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = label,
            color = TerminalPalette.inkDim,
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.width(80.dp),
        )
        Text(
            text = value,
            color = TerminalPalette.ink,
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun HowPage() {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        HowLine(tag = stringResource(R.string.pet_tag_mood), body = stringResource(R.string.pet_how_mood))
        HowLine(tag = stringResource(R.string.pet_tag_fed), body = stringResource(R.string.pet_how_fed))
        HowLine(tag = stringResource(R.string.pet_tag_energy), body = stringResource(R.string.pet_how_energy))
        HowLine(tag = stringResource(R.string.pet_tag_shake), body = stringResource(R.string.pet_how_shake))
        HowLine(tag = stringResource(R.string.pet_tag_idle), body = stringResource(R.string.pet_how_idle))
        HowLine(tag = "A", body = stringResource(R.string.pet_how_a))
        HowLine(tag = "B", body = stringResource(R.string.pet_how_b))
    }
}

@Composable
private fun HowLine(tag: String, body: String) {
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = tag,
            color = TerminalPalette.accent,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.width(72.dp),
        )
        Text(
            text = body,
            color = TerminalPalette.ink,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

private fun formatTokens(v: Int): String = when {
    v >= 1_000_000 -> "%.1fM".format(v / 1_000_000.0)
    v >= 1_000 -> "%.1fK".format(v / 1_000.0)
    else -> v.toString()
}

private fun formatNap(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds / 60) % 60
    return "%dh%02dm".format(h, m)
}
