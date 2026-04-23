// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.persona.PersonaController
import com.openvibble.persona.PersonaState
import com.openvibble.runtime.ParsedEntry
import com.openvibble.runtime.ProjectSummary
import com.openvibble.runtime.PromptRequest
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette

/**
 * Android parity with iOS `ClaudeSessionsView`. Renders INFO > CLAUDE body —
 * a horizontally scrollable chip row (`ALL` + one per project) above a
 * detail pane that swaps on selection.
 *
 * Data comes from `BridgeAppModel.projects`, which rebuilds from heartbeat
 * entries on every runtime tick. Selection is local to the composable;
 * when the current pick disappears from the project list we fall back to
 * `ALL`.
 */
@Composable
fun ClaudeSessionsView(
    model: BridgeAppModel,
    persona: PersonaController,
    modifier: Modifier = Modifier,
) {
    val projects by model.projects.collectAsState()
    val snapshot by model.snapshot.collectAsState()
    val prompt by model.prompt.collectAsState()
    val personaState by persona.state.collectAsState()

    var selectedProject by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(projects) {
        val current = selectedProject
        if (current != null && projects.none { it.name == current }) {
            selectedProject = null
        }
    }

    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        ChipRow(
            projects = projects,
            selected = selectedProject,
            onSelect = { selectedProject = it },
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(TerminalPalette.lcdDivider),
        )

        val pick = selectedProject?.let { name -> projects.firstOrNull { it.name == name } }
        if (pick != null) {
            ProjectDetailView(
                project = pick,
                prompt = if (pick.hasPendingPrompt) prompt else null,
            )
        } else {
            AllOverview(
                total = snapshot.total,
                running = snapshot.running,
                waiting = snapshot.waiting,
                personaState = personaState,
                tokensToday = snapshot.tokensToday,
            )
        }
    }
}

@Composable
private fun ChipRow(
    projects: List<ProjectSummary>,
    selected: String?,
    onSelect: (String?) -> Unit,
) {
    val scroll = rememberScrollState()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(scroll),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Chip(
            title = "ALL",
            isSelected = selected == null,
            onClick = { onSelect(null) },
        )
        projects.forEach { project ->
            Chip(
                title = project.name,
                isSelected = selected == project.name,
                trailing = { ChipTrailing(project) },
                onClick = { onSelect(project.name) },
            )
        }
    }
}

@Composable
private fun Chip(
    title: String,
    isSelected: Boolean,
    trailing: (@Composable () -> Unit)? = null,
    onClick: () -> Unit,
) {
    val bg = if (isSelected) TerminalPalette.ink else TerminalPalette.lcdPanel.copy(alpha = 0.6f)
    val fg = if (isSelected) TerminalPalette.lcdBg else TerminalPalette.ink
    Row(
        modifier = Modifier
            .background(bg, RoundedCornerShape(20.dp))
            .border(1.dp, TerminalPalette.inkDim.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = title,
            color = fg,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
        )
        if (trailing != null) trailing()
    }
}

@Composable
private fun ChipTrailing(project: ProjectSummary) {
    when {
        project.hasPendingPrompt -> Text(
            text = "!",
            color = TerminalPalette.bad,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        project.isActive -> Box(
            modifier = Modifier
                .size(6.dp)
                .background(TerminalPalette.good, CircleShape),
        )
    }
}

@Composable
private fun AllOverview(
    total: Int,
    running: Int,
    waiting: Int,
    personaState: PersonaState,
    tokensToday: Int,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        OverviewRow(label = "sessions", value = total.toString())
        OverviewRow(label = "running", value = running.toString())
        OverviewRow(label = "waiting", value = waiting.toString())
        OverviewRow(label = "state", value = personaStateLabel(personaState))
        OverviewRow(label = "tok/day", value = tokensToday.toString())
    }
}

@Composable
private fun OverviewRow(label: String, value: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = label,
            color = TerminalPalette.inkDim,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.width(82.dp),
        )
        Text(
            text = value,
            color = TerminalPalette.ink,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun ProjectDetailView(project: ProjectSummary, prompt: PromptRequest?) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        StatusRow(project)
        if (prompt != null) PromptRow(prompt)
        RecentHeader()
        RecentList(project.entries)
    }
}

@Composable
private fun StatusRow(project: ProjectSummary) {
    val (label, color) = when {
        project.hasPendingPrompt -> "waiting" to TerminalPalette.bad
        project.isActive -> "running" to TerminalPalette.good
        else -> "idle" to TerminalPalette.inkDim
    }
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = "status",
            color = TerminalPalette.inkDim,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.width(82.dp),
        )
        Text(
            text = label,
            color = color,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
    }
}

@Composable
private fun PromptRow(prompt: PromptRequest) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = "prompt",
            color = TerminalPalette.inkDim,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            modifier = Modifier.width(82.dp),
        )
        Text(
            text = formatPrompt(prompt),
            color = TerminalPalette.ink,
            fontSize = 12.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun RecentHeader() {
    Text(
        text = "RECENT",
        color = TerminalPalette.accentSoft,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
        modifier = Modifier.padding(top = 2.dp),
    )
}

@Composable
private fun RecentList(entries: List<ParsedEntry>) {
    if (entries.isEmpty()) {
        Text(
            text = "· nothing yet ·",
            color = TerminalPalette.inkDim,
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        return
    }
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier.verticalScroll(scroll),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        entries.take(RECENT_CAP).forEach { entry -> EntryRow(entry) }
    }
}

@Composable
private fun EntryRow(entry: ParsedEntry) {
    val detailParts = listOfNotNull(entry.event, entry.detail).filter { it.isNotEmpty() }
    val label = detailParts.joinToString(" ")
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            text = entry.time,
            color = TerminalPalette.inkDim,
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Text(
            text = label,
            color = TerminalPalette.ink.copy(alpha = 0.92f),
            fontSize = 11.sp,
            style = TextStyle(fontFamily = TerminalFonts.mono),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

private fun formatPrompt(prompt: PromptRequest): String {
    val tool = prompt.tool.trim()
    val hint = prompt.hint.trim()
    return when {
        tool.isEmpty() && hint.isEmpty() -> "—"
        hint.isEmpty() -> tool
        tool.isEmpty() -> hint
        else -> "$tool: $hint"
    }
}

private fun personaStateLabel(state: PersonaState): String = when (state) {
    PersonaState.SLEEP -> "sleep"
    PersonaState.IDLE -> "idle"
    PersonaState.BUSY -> "busy"
    PersonaState.ATTENTION -> "attention"
    PersonaState.CELEBRATE -> "celebrate"
    PersonaState.DIZZY -> "dizzy"
    PersonaState.HEART -> "heart"
}

private const val RECENT_CAP = 20
