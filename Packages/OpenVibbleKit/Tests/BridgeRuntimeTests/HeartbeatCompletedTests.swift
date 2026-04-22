// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import BridgeRuntime
@testable import BuddyStorage
@testable import BuddyProtocol

/// Heartbeat `completed: true` → one-shot callback (drives the 3s celebrate
/// animation in iOS, matching h5-demo triggerOneShot("celebrate", 3000) and
/// firmware P_CELEBRATE in data.h).
struct HeartbeatCompletedTests {
    @Test func completedTrueFiresCallback() {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        var callCount = 0
        runtime.onTaskCompleted = { callCount += 1 }

        _ = runtime.ingestLine("{\"total\":2,\"running\":0,\"waiting\":0,\"msg\":\"done\",\"entries\":[],\"completed\":true}")
        #expect(callCount == 1)
    }

    @Test func completedFalseDoesNotFireCallback() {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        var callCount = 0
        runtime.onTaskCompleted = { callCount += 1 }

        _ = runtime.ingestLine("{\"total\":2,\"running\":1,\"waiting\":0,\"msg\":\"working\",\"entries\":[],\"completed\":false}")
        #expect(callCount == 0)
    }

    @Test func missingCompletedFieldDoesNotFireCallback() {
        let runtime = BridgeRuntime(transferStore: CharacterTransferStore(rootURL: tempRoot()))
        var callCount = 0
        runtime.onTaskCompleted = { callCount += 1 }

        _ = runtime.ingestLine("{\"total\":1,\"running\":1,\"waiting\":0,\"msg\":\"still working\",\"entries\":[]}")
        #expect(callCount == 0)
    }

    @Test func decoderExposesCompletedOnHeartbeatSnapshot() throws {
        let line = "{\"total\":1,\"running\":0,\"waiting\":0,\"msg\":\"\",\"entries\":[],\"completed\":true}"
        let msg = try NDJSONCodec.decodeInboundLine(line)
        guard case let .heartbeat(snapshot) = msg else {
            Issue.record("Expected heartbeat"); return
        }
        #expect(snapshot.completed == true)
    }

    private func tempRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }
}
