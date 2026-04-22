// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import BridgeRuntime
@testable import BuddyStorage
@testable import BuddyProtocol
@testable import BuddyPersona

/// Verifies parity with claude-desktop-buddy firmware `cmd:"species"` handling:
/// valid idx [0..<18] saves to PersonaSelection + ACK ok;
/// sentinel 0xFF restores GIF / keeps current builtin;
/// out-of-range idx yields ACK false.
///
/// BridgeRuntime writes to `UserDefaults.standard`, which is shared process
/// state — run serialized so the three selection-reading tests don't race.
@Suite(.serialized)
struct BridgeRuntimeSpeciesTests {
    @Test func validIdxSavesAsciiSpeciesAndAcksOk() throws {
        let defaults = ephemeralDefaults()
        // Seed to a non-matching value so we can observe the write.
        PersonaSelection.save(.asciiCat, defaults: defaults)
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))

        var observed: Int?
        runtime.onSpeciesChanged = { observed = $0 }

        let lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":7}")
        #expect(lines.count == 1)

        let ack = try decode(ack: lines[0])
        #expect(ack.ack == "species")
        #expect(ack.ok == true)
        #expect(ack.error == nil)
        #expect(observed == 7)

        // The callback fires regardless of UserDefaults domain, so assert
        // against the selection read from the standard domain — this matches
        // production behaviour where BridgeRuntime writes to .standard.
        if case .asciiSpecies(let idx) = PersonaSelection.load() {
            #expect(idx == 7)
        } else {
            Issue.record("Expected PersonaSelection to be asciiSpecies after valid idx")
        }
    }

    @Test func sentinelRestoresGifKeepsBuiltinWhenAlreadyGif() throws {
        // Ensure current selection is a GIF persona so sentinel should not
        // overwrite it.
        PersonaSelection.save(.builtin(name: "bufo"))
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        var observed: Int?
        runtime.onSpeciesChanged = { observed = $0 }

        let lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":255}")
        let ack = try decode(ack: lines[0])
        #expect(ack.ok == true)
        #expect(observed == 0xFF)
        // Should still be the builtin; sentinel preserves GIF selection.
        if case .builtin(let name) = PersonaSelection.load() {
            #expect(name == "bufo")
        } else {
            Issue.record("Sentinel overwrote builtin selection")
        }
    }

    @Test func sentinelFallsBackToAsciiCatWhenNoGifSelected() throws {
        PersonaSelection.save(.asciiSpecies(idx: 3))
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        let lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":255}")
        let ack = try decode(ack: lines[0])
        #expect(ack.ok == true)
        #expect(PersonaSelection.load() == .asciiCat)
    }

    @Test func negativeIdxAcksFalse() throws {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        let lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":-1}")
        let ack = try decode(ack: lines[0])
        #expect(ack.ok == false)
        #expect(ack.ack == "species")
        #expect(ack.error == "invalid idx")
    }

    @Test func outOfRangeIdxAcksFalse() throws {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        let lines = runtime.ingestLine("{\"cmd\":\"species\",\"idx\":100}")
        let ack = try decode(ack: lines[0])
        #expect(ack.ok == false)
        #expect(ack.error == "invalid idx")
    }

    // MARK: - Helpers

    private func decode(ack line: String) throws -> BridgeAck {
        try NDJSONCodec.decoder.decode(BridgeAck.self, from: Data(line.utf8))
    }

    private func tempRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: "species.tests.\(UUID().uuidString)")!
    }
}
