// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum HookRegistrationStatus: Equatable, Sendable {
    case registered
    case partiallyRegistered(missing: [HookEvent])
    case notRegistered
}

public struct HookRegistrar: Sendable {
    public static let marker = "# OVD-MANAGED-v1"
    public let settingsURL: URL
    public let portFilePath: String

    public init(settingsURL: URL, portFilePath: String) {
        self.settingsURL = settingsURL
        self.portFilePath = portFilePath
    }

    public static func defaultSettingsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
    }

    public func register() throws {
        var root = try loadRootOrEmpty()
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for event in HookEvent.allCases {
            var arr = hooks[event.rawValue] as? [[String: Any]] ?? []
            let managed = arr.contains { group in
                let inner = group["hooks"] as? [[String: Any]] ?? []
                return inner.contains { ($0["command"] as? String ?? "").contains(Self.marker) }
            }
            if !managed {
                arr.append([
                    "hooks": [[
                        "type": "command",
                        "command": makeCommand(for: event)
                    ]]
                ])
                hooks[event.rawValue] = arr
            }
        }

        root["hooks"] = hooks
        try persist(root)
    }

    public func unregister() throws {
        var root = try loadRootOrEmpty()
        guard var hooks = root["hooks"] as? [String: Any] else { return }

        for (key, value) in hooks {
            guard var arr = value as? [[String: Any]] else { continue }
            arr = arr.compactMap { group -> [String: Any]? in
                let inner = (group["hooks"] as? [[String: Any]] ?? []).filter {
                    !(($0["command"] as? String ?? "").contains(Self.marker))
                }
                if inner.isEmpty {
                    return nil
                }
                var out = group
                out["hooks"] = inner
                return out
            }
            if arr.isEmpty { hooks.removeValue(forKey: key) }
            else { hooks[key] = arr }
        }

        if hooks.isEmpty {
            root.removeValue(forKey: "hooks")
        } else {
            root["hooks"] = hooks
        }
        try persist(root)
    }

    public func status() throws -> HookRegistrationStatus {
        let root = try loadRootOrEmpty()
        let hooks = root["hooks"] as? [String: Any] ?? [:]
        let missing = HookEvent.allCases.filter { event in
            let arr = hooks[event.rawValue] as? [[String: Any]] ?? []
            return !arr.contains { group in
                let inner = group["hooks"] as? [[String: Any]] ?? []
                return inner.contains { ($0["command"] as? String ?? "").contains(Self.marker) }
            }
        }
        if missing.isEmpty { return .registered }
        if missing.count == HookEvent.allCases.count { return .notRegistered }
        return .partiallyRegistered(missing: missing)
    }

    private func loadRootOrEmpty() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        if data.isEmpty { return [:] }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func persist(_ root: [String: Any]) throws {
        let dir = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        // JSONSerialization escapes forward slashes (\/) which is valid JSON but noisy for humans.
        // The Claude Code settings.json is user-edited; keep slashes raw.
        let text = String(data: data, encoding: .utf8)?.replacingOccurrences(of: "\\/", with: "/") ?? ""
        try Data(text.utf8).write(to: settingsURL, options: [.atomic])
    }

    private func makeCommand(for event: HookEvent) -> String {
        let port = "$(jq -r .port \(portFilePath) 2>/dev/null)"
        let token = "$(jq -r .token \(portFilePath) 2>/dev/null)"
        switch event {
        case .permissionRequest:
            return "curl -s --max-time 30 -H \"X-OVD-Token: \(token)\" http://127.0.0.1:\(port)/permission-request -d @- 2>/dev/null || echo '{}' \(Self.marker)"
        case .preToolUse:
            return fireAndForget(path: "pretooluse", port: port, token: token)
        case .userPromptSubmit:
            return fireAndForget(path: "prompt", port: port, token: token)
        case .stop:
            return fireAndForget(path: "stop", port: port, token: token)
        case .stopFailure:
            return fireAndForget(path: "stop-failure", port: port, token: token)
        case .notification:
            return fireAndForget(path: "notification", port: port, token: token)
        case .sessionStart:
            return fireAndForget(path: "session-start", port: port, token: token)
        case .sessionEnd:
            return fireAndForget(path: "session-end", port: port, token: token)
        case .subagentStart:
            return fireAndForget(path: "subagent-start", port: port, token: token)
        case .subagentStop:
            return fireAndForget(path: "subagent-stop", port: port, token: token)
        }
    }

    private func fireAndForget(path: String, port: String, token: String) -> String {
        "curl -s --max-time 5 -H \"X-OVD-Token: \(token)\" http://127.0.0.1:\(port)/\(path) -d @- >/dev/null 2>&1 \(Self.marker)"
    }
}
