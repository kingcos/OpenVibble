import Foundation
import BuddyPersona

/// Maps firmware species index (see `PersonaSpeciesCatalog.names`) to an
/// `ASCIIAnimation` provider. Only idx 4 (cat) has full frames today; other
/// indices fall back to cat so the UI never blanks. Drop in additional frame
/// tables here as they land.
public enum SpeciesRegistry {
    public static func animation(forIdx idx: Int, state: PersonaState) -> ASCIIAnimation {
        switch idx {
        case 4: return CatSpecies.animation(for: state)
        default: return CatSpecies.animation(for: state)
        }
    }
}
