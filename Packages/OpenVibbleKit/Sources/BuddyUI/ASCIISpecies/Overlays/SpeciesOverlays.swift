import BuddyPersona

enum SpeciesOverlays {
    static let byNameAndState: [String: [PersonaState: [Overlay]]] = [
        "cat": CatOverlays.all,
        // future: "duck": DuckOverlays.all, etc. — added per species.
    ]

    static func overlays(for name: String, state: PersonaState) -> [Overlay] {
        byNameAndState[name]?[state] ?? []
    }
}
