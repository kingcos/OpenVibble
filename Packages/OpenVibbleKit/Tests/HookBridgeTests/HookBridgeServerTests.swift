// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Network
import Testing
@testable import HookBridge

@Suite("HookBridgeServer")
struct HookBridgeServerTests {
    @Test func healthEndpointReturnsJSON() async throws {
        let server = HookBridgeServer(token: "secret") { _, _ in .ignore }
        let port = try await server.start()
        defer { Task { await server.stop() } }

        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = response as! HTTPURLResponse
        #expect(http.statusCode == 200)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["name"] as? String == "OpenVibbleDesktop")
    }

    @Test func missingTokenReturns401() async throws {
        let server = HookBridgeServer(token: "secret") { _, _ in .ignore }
        let port = try await server.start()
        defer { Task { await server.stop() } }

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/prompt")!)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        let (_, response) = try await URLSession.shared.data(for: req)
        #expect((response as! HTTPURLResponse).statusCode == 401)
    }

    @Test func permissionRequestWaitsForDecision() async throws {
        let server = HookBridgeServer(token: "t") { _, _ in
            return .pendingApproval(id: UUID(), payload: PreToolUsePayload.placeholder)
        }
        let port = try await server.start()
        defer { Task { await server.stop() } }

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/permission-request")!)
        req.httpMethod = "POST"
        req.setValue("t", forHTTPHeaderField: "X-OVD-Token")
        req.httpBody = Data("{\"session_id\":\"s\",\"cwd\":\"/a/b\",\"tool_name\":\"Bash\"}".utf8)

        let task = Task { try await URLSession.shared.data(for: req) }

        // Poll until a pending entry appears (up to 2s) to avoid race.
        var pendingId: UUID?
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            let ids = await server.pendingIDs
            if let id = ids.first { pendingId = id; break }
        }
        #expect(pendingId != nil)
        #expect(await server.pendingCount == 1)
        if let pendingId { await server.resolvePending(id: pendingId, decision: .allow) }

        let (data, response) = try await task.value
        #expect((response as! HTTPURLResponse).statusCode == 200)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let output = parsed?["hookSpecificOutput"] as? [String: Any]
        let decision = output?["decision"] as? [String: Any]
        #expect(decision?["behavior"] as? String == "allow")
    }

    @Test func preToolUseIsObservationOnly() async throws {
        let server = HookBridgeServer(token: "t") { _, _ in .ignore }
        let port = try await server.start()
        defer { Task { await server.stop() } }

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/pretooluse")!)
        req.httpMethod = "POST"
        req.setValue("t", forHTTPHeaderField: "X-OVD-Token")
        req.httpBody = Data("{\"session_id\":\"s\",\"cwd\":\"/a/b\",\"tool_name\":\"Bash\"}".utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        #expect((response as! HTTPURLResponse).statusCode == 204)
        #expect(data.isEmpty)
    }

    @Test func fireAndForgetEventsReturn204() async throws {
        let paths = ["/prompt", "/stop", "/stop-failure", "/notification",
                     "/session-start", "/session-end", "/subagent-start", "/subagent-stop"]
        let server = HookBridgeServer(token: "t") { _, _ in .ignore }
        let port = try await server.start()
        defer { Task { await server.stop() } }

        for path in paths {
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!)
            req.httpMethod = "POST"
            req.setValue("t", forHTTPHeaderField: "X-OVD-Token")
            req.httpBody = Data("{}".utf8)
            let (_, response) = try await URLSession.shared.data(for: req)
            #expect((response as! HTTPURLResponse).statusCode == 204, "path \(path) should return 204")
        }
    }
}

extension PreToolUsePayload {
    static var placeholder: PreToolUsePayload {
        let json = "{\"session_id\":\"s\",\"cwd\":\"/a/b\",\"tool_name\":\"Bash\"}".data(using: .utf8)!
        return try! JSONDecoder().decode(PreToolUsePayload.self, from: json)
    }
}
