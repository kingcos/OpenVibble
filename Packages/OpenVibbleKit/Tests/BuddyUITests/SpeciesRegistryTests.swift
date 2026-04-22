// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import BuddyUI
import BuddyPersona

@Suite("Species Registry")
struct SpeciesRegistryTests {
    @Test
    func idleFrameIsDistinctAcrossFirmwareSpecies() {
        let rendered = (0..<PersonaSpeciesCatalog.count).map { idx in
            SpeciesRegistry.animation(forIdx: idx, state: .idle)
                .frame(at: 0)
                .lines
                .joined(separator: "\n")
        }
        #expect(Set(rendered).count == PersonaSpeciesCatalog.count)
    }

    @Test
    func invalidIndexFallsBackToCat() {
        let cat = SpeciesRegistry.animation(forIdx: 4, state: .idle).frame(at: 0)
        let invalid = SpeciesRegistry.animation(forIdx: 999, state: .idle).frame(at: 0)
        #expect(cat == invalid)
    }
}
