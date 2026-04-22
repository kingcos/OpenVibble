import BuddyPersona

enum SpeciesOverlays {
    static let byNameAndState: [String: [PersonaState: [Overlay]]] = [
        "cat": CatOverlays.all,
        "duck": DuckOverlays.all,
        // future: more species added per batch.
    ]

    static func overlays(for name: String, state: PersonaState) -> [Overlay] {
        byNameAndState[name]?[state] ?? []
    }
}
