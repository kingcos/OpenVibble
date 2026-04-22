import Testing
@testable import BuddyUI
import BuddyPersona

@Suite("Generated Species")
struct GeneratedSpeciesTests {
    @Test
    func allFirmwareSpeciesPresent() {
        for name in PersonaSpeciesCatalog.names {
            #expect(GeneratedSpecies.all[name] != nil, "missing species: \(name)")
        }
    }

    @Test
    func allStatesPresentPerSpecies() {
        for (name, states) in GeneratedSpecies.all {
            for state in PersonaState.allCases {
                #expect(states[state] != nil, "\(name) missing state \(state.slug)")
            }
        }
    }

    @Test
    func idleFramesDifferAcrossSpecies() {
        let idleFirstFrames = PersonaSpeciesCatalog.names.compactMap {
            GeneratedSpecies.all[$0]?[.idle]?.frames.first
        }.map { $0.joined(separator: "\n") }
        #expect(Set(idleFirstFrames).count == idleFirstFrames.count)
    }
}
