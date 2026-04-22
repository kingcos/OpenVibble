import Foundation
import Testing
@testable import BridgeRuntime
@testable import BuddyStorage
@testable import BuddyProtocol

struct BridgeRuntimeTests {
    @Test func emitsStatusAck() throws {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))

        let lines = runtime.ingestLine("{\"cmd\":\"status\"}")
        #expect(lines.count == 1)

        let ack = try NDJSONCodec.decoder.decode(BridgeAck.self, from: Data(lines[0].utf8))
        #expect(ack.ack == "status")
        #expect(ack.ok == true)
    }

    @Test func permissionRoundTripAfterHeartbeatPrompt() {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        _ = runtime.ingestLine("{" +
            "\"total\":1," +
            "\"running\":0," +
            "\"waiting\":1," +
            "\"msg\":\"approve\"," +
            "\"entries\":[\"line\"]," +
            "\"prompt\":{\"id\":\"req_1\",\"tool\":\"Bash\",\"hint\":\"ls\"}" +
        "}")

        let permission = runtime.respondPermission(.once)
        #expect(permission != nil)
        #expect(permission?.contains("\"cmd\":\"permission\"") == true)
        #expect(permission?.contains("\"id\":\"req_1\"") == true)
    }

    /// After responding to a prompt the runtime must clear its local
    /// `pendingPrompt()` immediately so the UI (Home panel, Live Activity
    /// island) doesn't keep offering Approve/Deny while the BLE round-trip
    /// completes. Protects the Dynamic Island "no visible reaction" fix in
    /// `BridgeAppModel.respondPermission`.
    @Test func respondPermissionClearsPendingPromptOptimistically() {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        _ = runtime.ingestLine("{" +
            "\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
            "\"prompt\":{\"id\":\"req_42\",\"tool\":\"Bash\",\"hint\":\"rm -rf\"}" +
        "}")
        #expect(runtime.pendingPrompt()?.id == "req_42")

        _ = runtime.respondPermission(.deny)
        #expect(runtime.pendingPrompt() == nil)

        // A second respond with no live prompt returns nil (cannot double-answer).
        #expect(runtime.respondPermission(.once) == nil)
    }

    /// A heartbeat echoing the just-answered prompt id must not re-seat it.
    /// Without idempotency we would briefly restore the prompt between the
    /// response being sent and the desktop's next heartbeat clearing it,
    /// making the island flicker the Approve/Deny buttons back on.
    @Test func heartbeatWithAnsweredPromptIdIsIgnored() {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        _ = runtime.ingestLine("{" +
            "\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
            "\"prompt\":{\"id\":\"req_77\",\"tool\":\"Write\",\"hint\":\"\"}" +
        "}")
        _ = runtime.respondPermission(.once)
        #expect(runtime.pendingPrompt() == nil)

        // Stale heartbeat still carrying the same prompt id: must stay cleared.
        _ = runtime.ingestLine("{" +
            "\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
            "\"prompt\":{\"id\":\"req_77\",\"tool\":\"Write\",\"hint\":\"\"}" +
        "}")
        #expect(runtime.pendingPrompt() == nil)

        // A NEW prompt id is a genuinely new request — must surface it.
        _ = runtime.ingestLine("{" +
            "\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
            "\"prompt\":{\"id\":\"req_78\",\"tool\":\"Bash\",\"hint\":\"\"}" +
        "}")
        #expect(runtime.pendingPrompt()?.id == "req_78")

        // After responding to req_78 and the desktop confirms (no prompt in
        // heartbeat), the answered-id latch must reset so a future heartbeat
        // reusing req_78 (unlikely but possible after a full session cycle)
        // is accepted again.
        _ = runtime.respondPermission(.deny)
        _ = runtime.ingestLine("{\"total\":1,\"running\":0,\"waiting\":0,\"msg\":\"ok\",\"entries\":[]}")
        #expect(runtime.pendingPrompt() == nil)
        _ = runtime.ingestLine("{" +
            "\"total\":1,\"running\":0,\"waiting\":1,\"msg\":\"approve\",\"entries\":[]," +
            "\"prompt\":{\"id\":\"req_78\",\"tool\":\"Bash\",\"hint\":\"\"}" +
        "}")
        #expect(runtime.pendingPrompt()?.id == "req_78")
    }

    @Test func protocolReplayWithTransferFlow() throws {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))

        _ = runtime.ingestLine("{\"time\":[1775731234,-25200]}")
        _ = runtime.ingestLine("{\"total\":2,\"running\":1,\"waiting\":0,\"msg\":\"working\",\"entries\":[\"10:42 git push\"],\"tokens\":100,\"tokens_today\":12}")

        let beginAck = runtime.ingestLine("{\"cmd\":\"char_begin\",\"name\":\"bufo\",\"total\":5}")
        _ = runtime.ingestLine("{\"cmd\":\"file\",\"path\":\"manifest.json\",\"size\":5}")
        _ = runtime.ingestLine("{\"cmd\":\"chunk\",\"d\":\"aGVsbG8=\"}")
        let fileEndAck = runtime.ingestLine("{\"cmd\":\"file_end\"}")
        let charEndAck = runtime.ingestLine("{\"cmd\":\"char_end\"}")

        #expect(beginAck.count == 1)
        #expect(fileEndAck.count == 1)
        #expect(charEndAck.count == 1)

        let begin = try NDJSONCodec.decoder.decode(BridgeAck.self, from: Data(beginAck[0].utf8))
        let fileEnd = try NDJSONCodec.decoder.decode(BridgeAck.self, from: Data(fileEndAck[0].utf8))
        let charEnd = try NDJSONCodec.decoder.decode(BridgeAck.self, from: Data(charEndAck[0].utf8))

        #expect(begin.ok)
        #expect(fileEnd.ok)
        #expect(charEnd.ok)

        let snapshot = runtime.currentSnapshot()
        #expect(snapshot.total == 2)
        #expect(snapshot.msg == "working")
    }

    private func tempRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }
}
