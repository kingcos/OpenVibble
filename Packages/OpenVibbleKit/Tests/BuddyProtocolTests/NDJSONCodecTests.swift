// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import BuddyProtocol

struct NDJSONCodecTests {
    @Test func framerHandlesStickyAndSplitPackets() throws {
        var framer = NDJSONLineFramer()
        let part1 = Data("{\"a\":1}\n{\"b\":2".utf8)
        let lines1 = try framer.ingest(part1)
        #expect(lines1 == ["{\"a\":1}"])

        let part2 = Data("}\n".utf8)
        let lines2 = try framer.ingest(part2)
        #expect(lines2 == ["{\"b\":2}"])
    }

    @Test func decodeHeartbeatAndCommand() throws {
        let heartbeatLine = """
        {"total":3,"running":1,"waiting":1,"msg":"approve: Bash","entries":["10:42 git push"],"tokens":100,"tokens_today":20,"prompt":{"id":"req_1","tool":"Bash","hint":"rm -rf /tmp"}}
        """

        let heartbeat = try NDJSONCodec.decodeInboundLine(heartbeatLine)
        if case let .heartbeat(snapshot) = heartbeat {
            #expect(snapshot.total == 3)
            #expect(snapshot.prompt?.id == "req_1")
        } else {
            Issue.record("Expected heartbeat")
        }

        let cmd = try NDJSONCodec.decodeInboundLine("{\"cmd\":\"status\"}")
        #expect(cmd == .command(.status))
    }

    @Test func encodePermissionCommandAsNDJSON() throws {
        let line = try NDJSONCodec.encodeLine(PermissionCommand(id: "req_abc", decision: .once))
        #expect(line.hasSuffix("\n"))
        #expect(line.contains("\"cmd\":\"permission\""))
        #expect(line.contains("\"decision\":\"once\""))
    }
}
