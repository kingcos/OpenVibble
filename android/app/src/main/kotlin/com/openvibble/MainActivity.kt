// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.AsciiBuddyView

/**
 * Minimal demo entry for the Android port. While the real
 * Home/Onboarding screens are being ported (task #11), this
 * activity renders a gallery of all species × states so the
 * ported ASCII animations can be verified on device.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            OpenVibbleTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
                    SpeciesGalleryScreen()
                }
            }
        }
    }
}

@Composable
private fun OpenVibbleTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Color.Black,
            surface = Color.Black,
            onBackground = Color.White,
            onSurface = Color.White,
        ),
        content = content,
    )
}

@Composable
private fun SpeciesGalleryScreen() {
    var selectedIdx by remember { mutableIntStateOf(PersonaSpeciesCatalog.names.indexOf("cat")) }
    Column(modifier = Modifier.fillMaxSize()) {
        Text(
            text = "OPENVIBBLE · ANDROID PREVIEW",
            color = Color(0xFFC2A6C2.toInt()),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            modifier = Modifier.padding(12.dp),
        )
        SpeciesPicker(selectedIdx = selectedIdx, onSelect = { selectedIdx = it })
        Spacer(Modifier.height(4.dp))
        StateGallery(speciesIdx = selectedIdx)
    }
}

@Composable
private fun SpeciesPicker(selectedIdx: Int, onSelect: (Int) -> Unit) {
    val scroll = rememberScrollState()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(scroll)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        PersonaSpeciesCatalog.names.forEachIndexed { idx, name ->
            val isSelected = idx == selectedIdx
            Box(
                modifier = Modifier
                    .padding(end = 8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (isSelected) Color(0xFF2A2A2A) else Color.Transparent)
                    .clickable { onSelect(idx) }
                    .padding(horizontal = 10.dp, vertical = 6.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = name.uppercase(),
                    color = if (isSelected) Color.White else Color(0xFF808080),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }
    }
}

@Composable
private fun StateGallery(speciesIdx: Int) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(PersonaState.values().toList()) { state ->
            Column(modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(6.dp))
                .background(Color(0xFF101010))
                .padding(12.dp)
            ) {
                Text(
                    text = state.slug.uppercase(),
                    color = Color(0xFF808080),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                )
                Spacer(Modifier.height(6.dp))
                AsciiBuddyView(state = state, speciesIdx = speciesIdx)
            }
        }
    }
}
