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
