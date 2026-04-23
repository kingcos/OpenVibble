// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.os.Build
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import coil.ImageLoader
import coil.compose.AsyncImage
import coil.decode.GifDecoder
import coil.decode.ImageDecoderDecoder
import coil.request.ImageRequest
import com.openvibble.persona.InstalledPersona
import com.openvibble.persona.PersonaState
import kotlinx.coroutines.delay
import java.io.File

/**
 * Android parity with iOS `GIFView` (Packages/OpenVibbleKit/Sources/BuddyUI/GIFView.swift).
 *
 * Picks the file list for the current [state]'s slug, falling back to `idle`
 * then the first manifest slug — mirrors `urlsForState()`. Renders via Coil's
 * animated decoder so per-frame GIF delays are honoured natively.
 *
 * When a state declares multiple variant files (iOS `Variants`), cycles to
 * the next one every [VARIANT_DWELL_MS] — Coil redraws automatically when the
 * model URL changes.
 */
@Composable
fun GifBuddyView(
    persona: InstalledPersona,
    state: PersonaState,
    modifier: Modifier = Modifier,
) {
    val files = remember(persona.id, state) { resolveFiles(persona, state) }
    var variantIdx by remember(persona.id, state) { mutableIntStateOf(0) }

    LaunchedEffect(persona.id, state, files.size) {
        if (files.size <= 1) return@LaunchedEffect
        while (true) {
            delay(VARIANT_DWELL_MS)
            variantIdx = (variantIdx + 1) % files.size
        }
    }

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        val current = files.getOrNull(variantIdx % files.size.coerceAtLeast(1))
        if (current != null) {
            val context = LocalContext.current
            val loader = remember(context) {
                ImageLoader.Builder(context).components {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) add(ImageDecoderDecoder.Factory())
                    else add(GifDecoder.Factory())
                }.build()
            }
            AsyncImage(
                model = ImageRequest.Builder(context)
                    .data(current)
                    .crossfade(false)
                    .build(),
                contentDescription = null,
                imageLoader = loader,
                contentScale = ContentScale.Fit,
                filterQuality = FilterQuality.None,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

/**
 * Mirrors iOS [GIFView.urlsForState]: exact-slug match first, then `idle`,
 * then the first manifest key as a last resort. Returns a flat file list so
 * callers only need one index to track variant cycling.
 */
private fun resolveFiles(persona: InstalledPersona, state: PersonaState): List<File> {
    val exact = persona.fileFor(state.slug)
    if (exact.isNotEmpty()) return exact
    val idleFallback = persona.fileFor(PersonaState.IDLE.slug)
    if (idleFallback.isNotEmpty()) return idleFallback
    val firstSlug = persona.manifest.states.keys.sorted().firstOrNull() ?: return emptyList()
    return persona.fileFor(firstSlug)
}

/** Same 5s dwell iOS uses before rotating to the next variant. */
private const val VARIANT_DWELL_MS: Long = 5_000L
