// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.R
import com.openvibble.persona.InstalledPersona
import com.openvibble.persona.PersonaSelectionStore
import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.AsciiBuddyView
import com.openvibble.ui.terminal.TerminalBackground
import com.openvibble.ui.terminal.TerminalFonts
import com.openvibble.ui.terminal.TerminalPalette
import com.openvibble.ui.terminal.TerminalPanel
import java.util.Locale

/**
 * Android parity with iOS `SpeciesPickerSheet`. Shows a preview of the
 * selected species at the top and two collapsible panels below — the 18
 * built-in ASCII species (+ any builtin GIF personas) and any user-installed
 * GIF personas. Non-ASCII selections render via [GifBuddyView]; ASCII
 * fallbacks cover the case where the manifest can't be found on disk.
 */
@Composable
fun SpeciesPickerSheet(
    selection: PersonaSpeciesId,
    store: PersonaSelectionStore,
    builtin: List<InstalledPersona>,
    installed: List<InstalledPersona>,
    onSelect: (PersonaSpeciesId) -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var current by remember(selection.rawValue) { mutableStateOf(selection) }

    Box(modifier = modifier.fillMaxSize()) {
        TerminalBackground()

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.safeDrawing),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { Header(onClose = onClose) }

            item {
                TerminalPanel(title = stringResource(R.string.species_panel_preview)) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        PreviewSpeciesView(current, builtin, installed)
                    }
                }
            }

            item {
                TerminalPanel(
                    title = stringResource(R.string.species_panel_builtin),
                    collapsible = true,
                    collapsedByDefault = true,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        PersonaSpeciesCatalog.names.forEachIndexed { idx, name ->
                            SpeciesRow(
                                title = "ASCII (${name.replaceFirstChar { it.titlecase(Locale.getDefault()) }})",
                                subtitle = if (idx == ASCII_DEFAULT_IDX) stringResource(R.string.species_default) else "idx $idx",
                                selected = matches(current, asciiIdFor(idx)),
                                onClick = {
                                    val id = asciiIdFor(idx)
                                    current = id
                                    store.save(id)
                                    onSelect(id)
                                },
                            )
                        }
                        builtin.forEach { persona ->
                            val id = PersonaSpeciesId.Builtin(persona.name)
                            SpeciesRow(
                                title = persona.manifest.name.replaceFirstChar { it.titlecase(Locale.getDefault()) },
                                subtitle = stringResource(R.string.species_subtitle_states, persona.manifest.states.size),
                                selected = matches(current, id),
                                onClick = {
                                    current = id
                                    store.save(id)
                                    onSelect(id)
                                },
                            )
                        }
                    }
                }
            }

            item {
                TerminalPanel(
                    title = stringResource(R.string.species_panel_installed),
                    collapsible = true,
                    collapsedByDefault = true,
                ) {
                    if (installed.isEmpty()) {
                        Text(
                            text = stringResource(R.string.species_empty_installed),
                            color = TerminalPalette.inkDim,
                            fontSize = 12.sp,
                            style = TextStyle(fontFamily = TerminalFonts.mono),
                        )
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            installed.forEach { persona ->
                                val id = PersonaSpeciesId.Installed(persona.name)
                                SpeciesRow(
                                    title = persona.manifest.name,
                                    subtitle = stringResource(R.string.species_subtitle_states, persona.manifest.states.size),
                                    selected = matches(current, id),
                                    onClick = {
                                        current = id
                                        store.save(id)
                                        onSelect(id)
                                    },
                                )
                            }
                        }
                    }
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun Header(onClose: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.species_title),
            color = TerminalPalette.ink,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            style = TextStyle(fontFamily = TerminalFonts.mono),
        )
        Spacer(Modifier.weight(1f))
        Box(
            modifier = Modifier
                .background(
                    TerminalPalette.lcdPanel.copy(alpha = 0.6f),
                    RoundedCornerShape(14.dp),
                )
                .border(
                    1.dp,
                    TerminalPalette.inkDim.copy(alpha = 0.5f),
                    RoundedCornerShape(14.dp),
                )
                .clickable(onClick = onClose)
                .padding(horizontal = 14.dp, vertical = 6.dp),
        ) {
            Text(
                text = stringResource(R.string.common_done),
                color = TerminalPalette.ink,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                style = TextStyle(fontFamily = TerminalFonts.mono, letterSpacing = 1.sp),
            )
        }
    }
}

@Composable
private fun PreviewSpeciesView(
    selection: PersonaSpeciesId,
    builtin: List<InstalledPersona>,
    installed: List<InstalledPersona>,
) {
    when (selection) {
        is PersonaSpeciesId.AsciiCat ->
            AsciiBuddyView(state = PersonaState.IDLE, modifier = Modifier.scale(0.72f))
        is PersonaSpeciesId.AsciiSpecies ->
            AsciiBuddyView(
                state = PersonaState.IDLE,
                speciesIdx = selection.idx,
                modifier = Modifier.scale(0.72f),
            )
        is PersonaSpeciesId.Builtin -> {
            val persona = builtin.firstOrNull { it.name == selection.name }
            if (persona != null) {
                GifBuddyView(
                    persona = persona,
                    state = PersonaState.IDLE,
                    modifier = Modifier.scale(0.72f),
                )
            } else {
                AsciiBuddyView(state = PersonaState.IDLE, modifier = Modifier.scale(0.72f))
            }
        }
        is PersonaSpeciesId.Installed -> {
            val persona = installed.firstOrNull { it.name == selection.name }
            if (persona != null) {
                GifBuddyView(
                    persona = persona,
                    state = PersonaState.IDLE,
                    modifier = Modifier.scale(0.72f),
                )
            } else {
                AsciiBuddyView(state = PersonaState.IDLE, modifier = Modifier.scale(0.72f))
            }
        }
    }
}

@Composable
private fun SpeciesRow(
    title: String,
    subtitle: String?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val panelBg = TerminalPalette.lcdPanel.copy(alpha = if (selected) 0.9f else 0.55f)
    val strokeColor: Color =
        if (selected) TerminalPalette.accent.copy(alpha = 0.85f)
        else TerminalPalette.inkDim.copy(alpha = 0.35f)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .background(panelBg, RoundedCornerShape(8.dp))
            .border(1.dp, strokeColor, RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = title,
                color = TerminalPalette.ink,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                style = TextStyle(fontFamily = TerminalFonts.mono),
            )
            if (!subtitle.isNullOrEmpty()) {
                Text(
                    text = subtitle,
                    color = TerminalPalette.inkDim,
                    fontSize = 10.sp,
                    style = TextStyle(fontFamily = TerminalFonts.mono),
                )
            }
        }
        if (selected) {
            Text(
                text = "OK",
                color = TerminalPalette.ink,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                style = TextStyle(fontFamily = TerminalFonts.mono),
            )
        }
    }
}

private const val ASCII_DEFAULT_IDX = 4

private fun asciiIdFor(idx: Int): PersonaSpeciesId =
    if (idx == ASCII_DEFAULT_IDX) PersonaSpeciesId.AsciiCat else PersonaSpeciesId.AsciiSpecies(idx)

private fun matches(current: PersonaSpeciesId, candidate: PersonaSpeciesId): Boolean =
    current.rawValue == candidate.rawValue
