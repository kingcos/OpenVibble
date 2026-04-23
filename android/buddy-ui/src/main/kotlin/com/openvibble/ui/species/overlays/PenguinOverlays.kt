// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species.overlays

import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.Overlay
import com.openvibble.ui.species.OverlayTint

/**
 * Penguin reuses the capybara overlay set except the first SLEEP z-char
 * uses CYAN for the cold-tint effect.
 */
object PenguinOverlays {
    val all: Map<PersonaState, List<Overlay>> = CapybaraOverlays.all.toMutableMap().apply {
        this[PersonaState.SLEEP] = penguinSleep
    }

    private val penguinSleep: List<Overlay> = run {
        val base = CapybaraOverlays.all[PersonaState.SLEEP]!!
        val firstZ = base[0]
        listOf(
            Overlay(
                char = firstZ.char,
                tint = OverlayTint.Rgb565(0x07FF), // CYAN instead of Dim
                path = firstZ.path,
                visibility = firstZ.visibility,
            ),
            base[1],
            base[2],
        )
    }
}
