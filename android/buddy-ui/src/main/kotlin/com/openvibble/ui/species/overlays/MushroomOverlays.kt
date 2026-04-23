// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species.overlays

import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.Overlay

/** Mushroom reuses the capybara overlay set 1:1 (iOS parity). */
object MushroomOverlays {
    val all: Map<PersonaState, List<Overlay>> = CapybaraOverlays.all
}
