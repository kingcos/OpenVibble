// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species.overlays

import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.Overlay

object SpeciesOverlays {
    private val byNameAndState: Map<String, Map<PersonaState, List<Overlay>>> = mapOf(
        "cat" to CatOverlays.all,
        // future: more species ported incrementally per Ralph-loop batch.
    )

    fun overlays(name: String, state: PersonaState): List<Overlay> =
        byNameAndState[name]?.get(state) ?: emptyList()
}
