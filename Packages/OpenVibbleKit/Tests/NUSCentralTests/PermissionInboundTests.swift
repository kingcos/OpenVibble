import Foundation
import Testing
import BuddyProtocol
@testable import NUSCentral

@Suite("PermissionInbound")
struct PermissionInboundTests {
    @Test func decodesPermissionApprove() {
        let line = "{\"cmd\":\"permission\",\"id\":\"abc\",\"decision\":\"once\"}"
        let msg = CentralInboundDecoder.decode(line)
        guard case .permission(let command) = msg else {
            Issue.record("expected .permission, got \(msg)")
            return
        }
        #expect(command.id == "abc")
        #expect(command.decision == .once)
    }

    @Test func decodesPermissionDeny() {
        let line = "{\"cmd\":\"permission\",\"id\":\"xyz\",\"decision\":\"deny\"}"
        let msg = CentralInboundDecoder.decode(line)
        guard case .permission(let command) = msg else {
            Issue.record("expected .permission")
            return
        }
        #expect(command.decision == .deny)
    }
}
