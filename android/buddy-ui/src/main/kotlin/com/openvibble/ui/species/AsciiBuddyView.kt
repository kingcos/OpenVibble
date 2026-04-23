// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import com.openvibble.persona.PersonaState
import com.openvibble.ui.colorFromRgb565
import kotlinx.coroutines.delay

/**
 * Compose port of iOS ASCIIBuddyView. Drives the animation tick at 5Hz
 * (mirroring iOS `TimelineView(.periodic(by: 0.2))`) via a `LaunchedEffect`
 * with `delay(200)`. Uses a monotonically increasing `elapsed` counter so
 * parent recompositions don't reset the sequence.
 */
@Composable
fun AsciiBuddyView(
    state: PersonaState,
    speciesIdx: Int? = null,
    modifier: Modifier = Modifier,
) {
    val idx = speciesIdx ?: SpeciesRegistry.defaultIdx()
    var elapsed by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(TICK_PERIOD_MS)
            elapsed++
        }
    }
    val animation = remember(idx, state) { SpeciesRegistry.animation(idx, state) }
    val data = remember(idx, state) { SpeciesRegistry.stateData(idx, state) }
    val bodyColor = remember(idx, state) {
        colorFromRgb565(data?.colorRGB565 ?: DEFAULT_BODY_COLOR)
    }
    val frame = animation.frameAt(elapsed)
    val overlays = data?.overlays.orEmpty()

    Box(
        modifier = modifier.semantics { contentDescription = "OpenVibble pet, state: ${state.slug}" },
        contentAlignment = Alignment.TopStart,
    ) {
        Column {
            frame.lines.forEach { line ->
                Text(
                    text = line,
                    color = bodyColor,
                    maxLines = 1,
                    softWrap = false,
                    style = MONO_STYLE,
                )
            }
        }
        if (overlays.isNotEmpty()) {
            OverlayLayer(overlays = overlays, tick = elapsed, bodyColor = bodyColor)
        }
    }
}

@Composable
private fun OverlayLayer(
    overlays: List<Overlay>,
    tick: Int,
    bodyColor: Color,
) {
    overlays.forEach { overlay ->
        if (!OverlayRenderer.isVisible(overlay.visibility, tick)) return@forEach
        val p = OverlayRenderer.position(overlay.path, tick)
        Text(
            text = overlay.char,
            color = tintColor(overlay.tint, bodyColor),
            maxLines = 1,
            softWrap = false,
            style = MONO_STYLE,
            modifier = Modifier.offset(
                x = (p.col * CHAR_ADVANCE_DP).dp,
                y = (p.row * LINE_HEIGHT_DP).dp,
            ),
        )
    }
}

private fun tintColor(tint: OverlayTint, bodyColor: Color): Color = when (tint) {
    is OverlayTint.Dim -> Color.White.copy(alpha = 0.4f)
    is OverlayTint.White -> Color.White
    is OverlayTint.Body -> bodyColor
    is OverlayTint.Rgb565 -> colorFromRgb565(tint.raw)
}

private const val TICK_PERIOD_MS: Long = 200L
private const val DEFAULT_BODY_COLOR: Int = 0xC2A6
// Matched to size 22 monospaced-bold cell geometry on iOS.
private const val CHAR_ADVANCE_DP: Double = 13.2
private const val LINE_HEIGHT_DP: Double = 26.0

private val MONO_STYLE: TextStyle = TextStyle(
    fontFamily = FontFamily.Monospace,
    fontWeight = FontWeight.Bold,
    fontSize = 22.sp,
    lineHeight = 26.sp,
)
