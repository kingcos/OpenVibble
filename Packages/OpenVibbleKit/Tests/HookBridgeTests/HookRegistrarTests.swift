import Foundation
import Testing
@testable import HookBridge

@Suite("HookRegistrar")
struct HookRegistrarTests {
    private func tempSettings() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hookregistrar-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    @Test func registerIntoEmptyFile() throws {
        let url = tempSettings()
        let reg = HookRegistrar(settingsURL: url, portFilePath: "/Users/me/.claude/openvibble.port")
        try reg.register()
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = json?["hooks"] as? [String: Any]
        for event in HookEvent.allCases {
            #expect(hooks?[event.rawValue] != nil, "missing hook registration for \(event.rawValue)")
        }
    }

    @Test func registerEmbedsMarker() throws {
        let url = tempSettings()
        let reg = HookRegistrar(settingsURL: url, portFilePath: "/tmp/port")
        try reg.register()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("OVD-MANAGED-v1"))
        #expect(text.contains("/tmp/port"))
    }

    @Test func permissionRequestUses30sTimeout() throws {
        let url = tempSettings()
        try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").register()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("--max-time 30"))
        #expect(text.contains("permission-request"))
    }

    @Test func fireAndForgetEventsUse5sTimeout() throws {
        let url = tempSettings()
        try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").register()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("--max-time 5"))
        #expect(text.contains("/pretooluse"))
        #expect(text.contains("/session-start"))
        #expect(text.contains("/subagent-start"))
    }

    @Test func unregisterRemovesOnlyMarkedEntries() throws {
        let url = tempSettings()
        let existing: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    ["hooks": [["type": "command", "command": "echo user-hook"]]]
                ]
            ]
        ]
        try JSONSerialization.data(withJSONObject: existing, options: []).write(to: url)

        let reg = HookRegistrar(settingsURL: url, portFilePath: "/tmp/port")
        try reg.register()
        try reg.unregister()

        let after = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let hooks = after?["hooks"] as? [String: Any]
        let pre = hooks?["PreToolUse"] as? [[String: Any]]
        #expect(pre?.count == 1)
        let inner = (pre?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        #expect(inner == "echo user-hook")
    }

    @Test func statusDetectsFullyRegistered() throws {
        let url = tempSettings()
        try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").register()
        let status = try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").status()
        #expect(status == .registered)
    }

    @Test func statusDetectsNotRegistered() throws {
        let url = tempSettings()
        try "{}".write(to: url, atomically: true, encoding: .utf8)
        let status = try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").status()
        #expect(status == .notRegistered)
    }
}
