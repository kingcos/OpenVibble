// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species.overlays

import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.Overlay

object SpeciesOverlays {
    private val byNameAndState: Map<String, Map<PersonaState, List<Overlay>>> = mapOf(
        "cat" to CatOverlays.all,
        "duck" to DuckOverlays.all,
        "goose" to GooseOverlays.all,
        "capybara" to CapybaraOverlays.all,
        "turtle" to TurtleOverlays.all,
        "rabbit" to RabbitOverlays.all,
        "penguin" to PenguinOverlays.all,
        "mushroom" to MushroomOverlays.all,
        "cactus" to CactusOverlays.all,
        "owl" to OwlOverlays.all,
        "ghost" to GhostOverlays.all,
        "snail" to SnailOverlays.all,
        "robot" to RobotOverlays.all,
        "axolotl" to AxolotlOverlays.all,
        "blob" to BlobOverlays.all,
        "chonk" to ChonkOverlays.all,
        "dragon" to DragonOverlays.all,
        "octopus" to OctopusOverlays.all,
    )

    fun overlays(name: String, state: PersonaState): List<Overlay> =
        byNameAndState[name]?.get(state) ?: emptyList()
}
