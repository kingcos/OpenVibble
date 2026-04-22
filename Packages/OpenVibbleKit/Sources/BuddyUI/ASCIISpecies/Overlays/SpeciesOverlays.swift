// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import BuddyPersona

enum SpeciesOverlays {
    static let byNameAndState: [String: [PersonaState: [Overlay]]] = [
        "cat": CatOverlays.all,
        "duck": DuckOverlays.all,
        "goose": GooseOverlays.all,
        "turtle": TurtleOverlays.all,
        "capybara": CapybaraOverlays.all,
        "cactus": CactusOverlays.all,
        "rabbit": RabbitOverlays.all,
        "penguin": PenguinOverlays.all,
        "mushroom": MushroomOverlays.all,
        "ghost": GhostOverlays.all,
        "owl": OwlOverlays.all,
        "snail": SnailOverlays.all,
        "robot": RobotOverlays.all,
        "axolotl": AxolotlOverlays.all,
        "blob": BlobOverlays.all,
        "dragon": DragonOverlays.all,
        "octopus": OctopusOverlays.all,
        "chonk": ChonkOverlays.all,
        // future: more species added per batch.
    ]

    static func overlays(for name: String, state: PersonaState) -> [Overlay] {
        byNameAndState[name]?[state] ?? []
    }
}
