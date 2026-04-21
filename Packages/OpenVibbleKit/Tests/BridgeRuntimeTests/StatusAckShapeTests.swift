import Foundation
import Testing
@testable import BridgeRuntime
@testable import BuddyStorage
@testable import BuddyProtocol

/// Pins the `status` ACK shape to the firmware/h5 REFERENCE.md contract so
/// this iOS bridge stays a drop-in replacement. Required top-level fields:
/// `name, owner, sec, bat{pct,mV,mA,usb}, sys{up,heap,fsFree,fsTotal},
/// stats{appr,deny,vel,nap,lvl}`. `xfer{active,total,written}` is an iOS-only
/// extension tolerated by desktop.
struct StatusAckShapeTests {
    @Test func statusAckExposesFirmwareShape() throws {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        let lines = runtime.ingestLine("{\"cmd\":\"status\"}")
        try #require(lines.count == 1)

        let object = try jsonObject(from: lines[0])
        #expect(object["ack"] as? String == "status")
        #expect(object["ok"] as? Bool == true)

        guard let data = object["data"] as? [String: Any] else {
            Issue.record("status ACK missing data payload"); return
        }

        // Top-level keys (firmware parity).
        #expect(data["name"] is String)
        #expect(data["owner"] is String)
        #expect(data["sec"] is Bool)
        #expect(data["sec"] as? Bool == false) // iOS can't enforce LE-SC bonding.

        // bat sub-object.
        guard let bat = data["bat"] as? [String: Any] else {
            Issue.record("missing bat"); return
        }
        #expect(bat["pct"] != nil)
        #expect(bat["mV"] != nil)
        #expect(bat["mA"] != nil)
        #expect(bat["usb"] is Bool)

        // sys sub-object — this is the one being added in this round.
        guard let sys = data["sys"] as? [String: Any] else {
            Issue.record("missing sys"); return
        }
        #expect(sys["up"] != nil)
        #expect(sys["heap"] != nil)
        #expect(sys["fsFree"] != nil, "fsFree must be present to match REFERENCE.md")
        #expect(sys["fsTotal"] != nil, "fsTotal must be present to match REFERENCE.md")

        // stats sub-object.
        guard let stats = data["stats"] as? [String: Any] else {
            Issue.record("missing stats"); return
        }
        for key in ["appr", "deny", "vel", "nap", "lvl"] {
            #expect(stats[key] != nil, "stats.\(key) missing")
        }

        // iOS extension: still present for our own Home UI — firmware ignores.
        guard let xfer = data["xfer"] as? [String: Any] else {
            Issue.record("missing xfer (iOS extension)"); return
        }
        #expect(xfer["active"] is Bool)
        #expect(xfer["total"] != nil)
        #expect(xfer["written"] != nil)
    }

    @Test func sysUpIsSessionScopedAndNonNegative() throws {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        let lines = runtime.ingestLine("{\"cmd\":\"status\"}")
        let object = try jsonObject(from: lines[0])
        let data = object["data"] as? [String: Any] ?? [:]
        let sys = data["sys"] as? [String: Any] ?? [:]

        // Should be a non-negative, small number (just-started runtime).
        // Device-boot uptime would be huge; session uptime is ~0.
        if let up = sys["up"] as? Double {
            #expect(up >= 0)
            #expect(up < 600, "up=\(up) looks like device boot uptime, not session uptime")
        } else {
            Issue.record("sys.up not a number")
        }
    }

    // MARK: - Helpers

    private func jsonObject(from line: String) throws -> [String: Any] {
        let raw = try JSONSerialization.jsonObject(with: Data(line.utf8))
        return raw as? [String: Any] ?? [:]
    }

    private func tempRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }
}
