# Claude Code Hook Bridging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a localhost HTTP bridge to `OpenVibbleDesktop` that forwards Claude Code hook events to the iOS BLE buddy, supports in-app registration / unregistration of `~/.claude/settings.json`, and exposes the bridge via 5 tabs in the main window (Overview / Hooks / Test Panel / Bridge API / Settings).

**Architecture:** New SPM target `HookBridge` under `Packages/OpenVibbleKit` holds all pure logic + HTTP server (testable with `swift test`). `OpenVibbleDesktop` depends on it, wires state into `AppState`, and restructures `MainView` into a `TabView`. iOS code unchanged.

**Tech Stack:** Swift 6 / SwiftUI / `Network.framework` (`NWListener`) / existing `BuddyProtocol` + `NUSCentral` / `xcstrings` localization.

---

## File Structure

**New SPM target `HookBridge`** (Swift package `OpenVibbleKit`):
- `Sources/HookBridge/PortFile.swift` — port+token JSON file r/w at `~/.claude/openvibble.port`
- `Sources/HookBridge/HookEvent.swift` — event enum, payload structs, persona intent mapping
- `Sources/HookBridge/HookActivity.swift` — ring buffer of recent events + per-event stats
- `Sources/HookBridge/HookRegistrar.swift` — merge/unmerge managed hooks in `~/.claude/settings.json`
- `Sources/HookBridge/HookBridgeServer.swift` — `NWListener`-based HTTP server, endpoints, race primitive
- `Tests/HookBridgeTests/*.swift` — unit tests for above

**New UI files** (`OpenVibbleDesktop/`):
- `Views/Tabs/OverviewTab.swift` — connection + pending banner + recent activity
- `Views/Tabs/HooksTab.swift` — register button + event cards + log
- `Views/Tabs/TestPanelTab.swift` — migrated content from current `MainView`
- `Views/Tabs/BridgeDocsTab.swift` — API docs with copy buttons
- `Views/Tabs/SettingsTab.swift` — language + about
- `Views/PendingApprovalBanner.swift` — shared banner component
- `Views/EventCard.swift` — reusable event summary card

**Modified:**
- `Packages/OpenVibbleKit/Package.swift` — register HookBridge target + tests
- `project.yml` — add HookBridge product dependency to desktop target
- `OpenVibbleDesktop/OpenVibbleDesktop.entitlements` — remove `app-sandbox`
- `OpenVibbleDesktop/AppState.swift` — wire HookBridgeServer, expose `pendingApproval` + `hookActivity` + `registrationStatus`
- `OpenVibbleDesktop/Views/MainView.swift` — rewritten as TabView shell
- `OpenVibbleDesktop/Resources/Localizable.xcstrings` — new keys (en + zh-Hans)

---

## Task 1 — Register new `HookBridge` SPM target

**Files:**
- Modify: `Packages/OpenVibbleKit/Package.swift`

- [ ] **Step 1: Add product and targets to Package.swift**

Edit `Packages/OpenVibbleKit/Package.swift`. Add to `products` array:

```swift
.library(name: "HookBridge", targets: ["HookBridge"]),
```

Add to `targets` array:

```swift
.target(
    name: "HookBridge",
    dependencies: ["BuddyProtocol"]
),
.testTarget(
    name: "HookBridgeTests",
    dependencies: ["HookBridge"]
),
```

- [ ] **Step 2: Create empty source directories**

```bash
mkdir -p Packages/OpenVibbleKit/Sources/HookBridge
mkdir -p Packages/OpenVibbleKit/Tests/HookBridgeTests
# Placeholder so SwiftPM can resolve the empty target.
printf "// Namespace header for HookBridge target.\n" > Packages/OpenVibbleKit/Sources/HookBridge/HookBridge.swift
printf "// Placeholder test file.\nimport Testing\n@Test func placeholder() { #expect(true) }\n" > Packages/OpenVibbleKit/Tests/HookBridgeTests/PlaceholderTests.swift
```

- [ ] **Step 3: Verify package resolves and tests compile**

```bash
cd Packages/OpenVibbleKit && swift build && swift test --filter HookBridgeTests
```

Expected: build succeeds, `placeholder()` passes.

- [ ] **Step 4: Commit**

```bash
git add Packages/OpenVibbleKit/Package.swift Packages/OpenVibbleKit/Sources/HookBridge Packages/OpenVibbleKit/Tests/HookBridgeTests
git commit -m "Add HookBridge SPM target scaffold"
```

---

## Task 2 — `PortFile`

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/HookBridge/PortFile.swift`
- Create: `Packages/OpenVibbleKit/Tests/HookBridgeTests/PortFileTests.swift`

Write location: `~/.claude/openvibble.port`. Format: `{"port": Int, "token": String, "pid": Int, "version": Int}`.

- [ ] **Step 1: Write failing test**

Replace `Tests/HookBridgeTests/PlaceholderTests.swift` with `PortFileTests.swift`:

```swift
import Foundation
import Testing
@testable import HookBridge

@Suite("PortFile")
struct PortFileTests {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hookbridge-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func writeAndRead() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("openvibble.port")
        let payload = PortFile(port: 41847, token: "abc123", pid: 42, version: 1)
        try PortFileStore(url: url).write(payload)
        let read = try PortFileStore(url: url).read()
        #expect(read == payload)
    }

    @Test func removeIfExists() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("openvibble.port")
        let store = PortFileStore(url: url)
        try store.write(PortFile(port: 1, token: "t", pid: 2, version: 1))
        try store.remove()
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
        // Second remove is a no-op, not an error.
        try store.remove()
    }

    @Test func readMissingThrows() {
        let dir = tempDir()
        let url = dir.appendingPathComponent("missing.port")
        #expect(throws: Error.self) { try PortFileStore(url: url).read() }
    }

    @Test func filePermissionsAreUserOnly() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("openvibble.port")
        try PortFileStore(url: url).write(PortFile(port: 1, token: "t", pid: 2, version: 1))
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let perms = attrs[.posixPermissions] as? NSNumber
        #expect(perms?.int16Value == 0o600)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookBridgeTests
```

Expected: FAIL — `PortFile`, `PortFileStore` undefined.

- [ ] **Step 3: Implement PortFile.swift**

Create `Sources/HookBridge/PortFile.swift`:

```swift
import Foundation

public struct PortFile: Codable, Equatable, Sendable {
    public var port: Int
    public var token: String
    public var pid: Int
    public var version: Int

    public init(port: Int, token: String, pid: Int, version: Int) {
        self.port = port
        self.token = token
        self.pid = pid
        self.version = version
    }
}

public struct PortFileStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    /// `~/.claude/openvibble.port` for production use.
    public static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("openvibble.port", isDirectory: false)
    }

    public func write(_ payload: PortFile) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func read() throws -> PortFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PortFile.self, from: data)
    }

    public func remove() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        try fm.removeItem(at: url)
    }
}
```

Delete `Sources/HookBridge/HookBridge.swift` (the placeholder) and `Tests/HookBridgeTests/PlaceholderTests.swift`:

```bash
rm Packages/OpenVibbleKit/Sources/HookBridge/HookBridge.swift
rm Packages/OpenVibbleKit/Tests/HookBridgeTests/PlaceholderTests.swift
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookBridgeTests
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/OpenVibbleKit
git commit -m "Add PortFile store for hook bridge port/token file"
```

---

## Task 3 — `HookEvent` and persona intent mapping

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/HookBridge/HookEvent.swift`
- Create: `Packages/OpenVibbleKit/Tests/HookBridgeTests/HookEventTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Foundation
import Testing
@testable import HookBridge

@Suite("HookEvent")
struct HookEventTests {
    @Test func personaIntentForPending() {
        #expect(HookEvent.preToolUse.pendingPersonaIntent == .attention(overlay: .heart))
    }

    @Test func personaIntentForNonBlocking() {
        #expect(HookEvent.userPromptSubmit.transientPersonaIntent == .busy(duration: 1.0))
        #expect(HookEvent.stop.transientPersonaIntent == .celebrate(duration: 3.0))
        #expect(HookEvent.notification.transientPersonaIntent == .attention(duration: 2.0))
    }

    @Test func decisionIntent() {
        #expect(HookEvent.PermissionDecisionKind.allow.personaIntent == .celebrate(duration: 1.0))
        #expect(HookEvent.PermissionDecisionKind.deny.personaIntent == .dizzy(duration: 1.5))
        #expect(HookEvent.PermissionDecisionKind.ask.personaIntent == .idle)
    }

    @Test func projectNameFromCwd() {
        #expect(HookEvent.projectName(fromCwd: "/Users/foo/bar/claude-buddy-bridge-ios") == "claude-buddy-bridge-ios")
        #expect(HookEvent.projectName(fromCwd: "/") == nil)
        #expect(HookEvent.projectName(fromCwd: nil) == nil)
    }

    @Test func decodePreToolUsePayload() throws {
        let json = """
        {"session_id":"abc","cwd":"/a/b/proj","tool_name":"Bash","tool_input":{"command":"ls"}}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PreToolUsePayload.self, from: json)
        #expect(decoded.sessionId == "abc")
        #expect(decoded.cwd == "/a/b/proj")
        #expect(decoded.toolName == "Bash")
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookEventTests
```

- [ ] **Step 3: Implement HookEvent.swift**

```swift
import Foundation

public enum HookEvent: String, Codable, CaseIterable, Sendable {
    case preToolUse = "PreToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case stop = "Stop"
    case notification = "Notification"

    public enum PersonaIntent: Equatable, Sendable {
        case idle
        case busy(duration: TimeInterval)
        case celebrate(duration: TimeInterval)
        case attention(duration: TimeInterval)
        case attentionSticky(overlay: StickyOverlay)
        case dizzy(duration: TimeInterval)

        public static func attention(overlay: StickyOverlay) -> PersonaIntent {
            .attentionSticky(overlay: overlay)
        }
    }

    public enum StickyOverlay: Equatable, Sendable {
        case heart
    }

    public enum PermissionDecisionKind: String, Codable, Sendable {
        case allow
        case deny
        case ask

        public var personaIntent: PersonaIntent {
            switch self {
            case .allow: return .celebrate(duration: 1.0)
            case .deny: return .dizzy(duration: 1.5)
            case .ask: return .idle
            }
        }
    }

    /// Used while a PreToolUse approval is pending (sticky until resolved).
    public var pendingPersonaIntent: PersonaIntent {
        switch self {
        case .preToolUse: return .attention(overlay: .heart)
        default: return .idle
        }
    }

    /// Used for fire-and-forget events that just briefly animate the pet.
    public var transientPersonaIntent: PersonaIntent {
        switch self {
        case .preToolUse: return .attention(overlay: .heart)
        case .userPromptSubmit: return .busy(duration: 1.0)
        case .stop: return .celebrate(duration: 3.0)
        case .notification: return .attention(duration: 2.0)
        }
    }

    public static func projectName(fromCwd cwd: String?) -> String? {
        guard let cwd, !cwd.isEmpty else { return nil }
        let url = URL(fileURLWithPath: cwd).standardizedFileURL
        let last = url.lastPathComponent
        if last.isEmpty || last == "/" { return nil }
        return last
    }
}

public struct PreToolUsePayload: Codable, Sendable {
    public let sessionId: String?
    public let cwd: String?
    public let toolName: String?
    public let toolInput: [String: String]?
    public let transcriptPath: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case transcriptPath = "transcript_path"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionId = try? c.decode(String.self, forKey: .sessionId)
        self.cwd = try? c.decode(String.self, forKey: .cwd)
        self.toolName = try? c.decode(String.self, forKey: .toolName)
        self.transcriptPath = try? c.decode(String.self, forKey: .transcriptPath)
        // `tool_input` can be an arbitrary object. Coerce scalars to strings for display; drop nested.
        if let raw = try? c.decode([String: AnyCodable].self, forKey: .toolInput) {
            var flat: [String: String] = [:]
            for (k, v) in raw { flat[k] = v.stringified }
            self.toolInput = flat
        } else {
            self.toolInput = nil
        }
    }
}

/// Minimal any-codable helper for transcript-like JSON cells.
public struct AnyCodable: Decodable, Sendable {
    public let stringified: String
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { stringified = v }
        else if let v = try? c.decode(Int.self) { stringified = String(v) }
        else if let v = try? c.decode(Double.self) { stringified = String(v) }
        else if let v = try? c.decode(Bool.self) { stringified = String(v) }
        else { stringified = "…" }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookEventTests
```

- [ ] **Step 5: Commit**

```bash
git add Packages/OpenVibbleKit
git commit -m "Add HookEvent enum and persona intent mapping"
```

---

## Task 4 — `HookRegistrar`

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/HookBridge/HookRegistrar.swift`
- Create: `Packages/OpenVibbleKit/Tests/HookBridgeTests/HookRegistrarTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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
        #expect(hooks?["PreToolUse"] != nil)
        #expect(hooks?["UserPromptSubmit"] != nil)
        #expect(hooks?["Stop"] != nil)
        #expect(hooks?["Notification"] != nil)
    }

    @Test func registerEmbedsMarker() throws {
        let url = tempSettings()
        let reg = HookRegistrar(settingsURL: url, portFilePath: "/tmp/port")
        try reg.register()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("OVD-MANAGED-v1"))
        #expect(text.contains("/tmp/port"))
    }

    @Test func preToolUseUses30sTimeout() throws {
        let url = tempSettings()
        try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").register()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("--max-time 30"))
        #expect(text.contains("pretooluse"))
    }

    @Test func fireAndForgetEventsUse1sTimeout() throws {
        let url = tempSettings()
        try HookRegistrar(settingsURL: url, portFilePath: "/tmp/port").register()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("--max-time 1"))
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
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookRegistrarTests
```

- [ ] **Step 3: Implement HookRegistrar.swift**

```swift
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
        try data.write(to: settingsURL, options: [.atomic])
    }

    private func makeCommand(for event: HookEvent) -> String {
        let port = "$(jq -r .port \(portFilePath) 2>/dev/null)"
        let token = "$(jq -r .token \(portFilePath) 2>/dev/null)"
        switch event {
        case .preToolUse:
            return "curl -s --max-time 30 -H \"X-OVD-Token: \(token)\" http://127.0.0.1:\(port)/pretooluse -d @- 2>/dev/null || echo '{}' \(Self.marker)"
        case .userPromptSubmit:
            return "curl -s --max-time 1 -H \"X-OVD-Token: \(token)\" http://127.0.0.1:\(port)/prompt -d @- >/dev/null 2>&1; echo '{}' \(Self.marker)"
        case .stop:
            return "curl -s --max-time 1 -H \"X-OVD-Token: \(token)\" http://127.0.0.1:\(port)/stop -d @- >/dev/null 2>&1; echo '{}' \(Self.marker)"
        case .notification:
            return "curl -s --max-time 1 -H \"X-OVD-Token: \(token)\" http://127.0.0.1:\(port)/notification -d @- >/dev/null 2>&1; echo '{}' \(Self.marker)"
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookRegistrarTests
```

- [ ] **Step 5: Commit**

```bash
git add Packages/OpenVibbleKit
git commit -m "Add HookRegistrar for ~/.claude/settings.json merge/unmerge"
```

---

## Task 5 — `HookActivity`

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/HookBridge/HookActivity.swift`
- Create: `Packages/OpenVibbleKit/Tests/HookBridgeTests/HookActivityTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import Testing
@testable import HookBridge

@Suite("HookActivity")
struct HookActivityTests {
    @Test func appendIsMostRecentFirst() {
        var log = HookActivityLog(capacity: 50)
        log.append(HookActivityEntry(event: .stop, projectName: "a"))
        log.append(HookActivityEntry(event: .preToolUse, projectName: "b"))
        #expect(log.recent.first?.event == .preToolUse)
        #expect(log.recent.last?.event == .stop)
    }

    @Test func capacityIsEnforced() {
        var log = HookActivityLog(capacity: 3)
        for i in 0..<10 {
            log.append(HookActivityEntry(event: .stop, projectName: "p\(i)"))
        }
        #expect(log.recent.count == 3)
        #expect(log.recent.first?.projectName == "p9")
        #expect(log.recent.last?.projectName == "p7")
    }

    @Test func perEventStatsTracksCountAndLastFired() {
        var log = HookActivityLog(capacity: 10)
        let e1 = HookActivityEntry(event: .preToolUse, projectName: "a")
        let e2 = HookActivityEntry(event: .preToolUse, projectName: "b")
        let e3 = HookActivityEntry(event: .stop, projectName: "a")
        log.append(e1); log.append(e2); log.append(e3)
        #expect(log.stats(for: .preToolUse).todayCount == 2)
        #expect(log.stats(for: .stop).todayCount == 1)
        #expect(log.stats(for: .notification).todayCount == 0)
        #expect(log.stats(for: .preToolUse).lastFired == e2.firedAt)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement HookActivity.swift**

```swift
import Foundation

public struct HookActivityEntry: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let event: HookEvent
    public let projectName: String?
    public let toolName: String?
    public let decision: HookEvent.PermissionDecisionKind?
    public let firedAt: Date

    public init(
        id: UUID = UUID(),
        event: HookEvent,
        projectName: String? = nil,
        toolName: String? = nil,
        decision: HookEvent.PermissionDecisionKind? = nil,
        firedAt: Date = Date()
    ) {
        self.id = id
        self.event = event
        self.projectName = projectName
        self.toolName = toolName
        self.decision = decision
        self.firedAt = firedAt
    }
}

public struct HookEventStats: Equatable, Sendable {
    public var lastFired: Date?
    public var todayCount: Int
    public init(lastFired: Date? = nil, todayCount: Int = 0) {
        self.lastFired = lastFired
        self.todayCount = todayCount
    }
}

public struct HookActivityLog: Equatable, Sendable {
    public let capacity: Int
    public private(set) var recent: [HookActivityEntry] = []
    private var statsByEvent: [HookEvent: HookEventStats] = [:]

    public init(capacity: Int = 50) {
        self.capacity = capacity
    }

    public mutating func append(_ entry: HookActivityEntry) {
        recent.insert(entry, at: 0)
        if recent.count > capacity {
            recent.removeLast(recent.count - capacity)
        }
        var s = statsByEvent[entry.event] ?? HookEventStats()
        s.lastFired = entry.firedAt
        if Calendar.current.isDateInToday(entry.firedAt) {
            s.todayCount += 1
        }
        statsByEvent[entry.event] = s
    }

    public func stats(for event: HookEvent) -> HookEventStats {
        statsByEvent[event] ?? HookEventStats()
    }
}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add Packages/OpenVibbleKit
git commit -m "Add HookActivityLog ring buffer with per-event stats"
```

---

## Task 6 — `HookBridgeServer` (HTTP server)

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/HookBridge/HookBridgeServer.swift`
- Create: `Packages/OpenVibbleKit/Tests/HookBridgeTests/HookBridgeServerTests.swift`

Uses `Network.framework` `NWListener` bound to `127.0.0.1` on port `0` (random). The server parses minimal HTTP/1.1 requests (method + path + headers + body with `Content-Length`). Only needed methods: `POST` + `GET`.

- [ ] **Step 1: Write failing test**

```swift
import Foundation
import Network
import Testing
@testable import HookBridge

@Suite("HookBridgeServer")
struct HookBridgeServerTests {
    @Test func healthEndpointReturnsJSON() async throws {
        let server = HookBridgeServer(token: "secret") { _, _ in .ignore }
        let port = try await server.start()
        defer { server.stop() }

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
        defer { server.stop() }

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/prompt")!)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        let (_, response) = try await URLSession.shared.data(for: req)
        #expect((response as! HTTPURLResponse).statusCode == 401)
    }

    @Test func preToolUseWaitsForDecision() async throws {
        let server = HookBridgeServer(token: "t") { id, payload in
            return .pendingApproval(id: id, payload: payload)
        }
        let port = try await server.start()
        defer { server.stop() }

        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/pretooluse")!)
        req.httpMethod = "POST"
        req.setValue("t", forHTTPHeaderField: "X-OVD-Token")
        req.httpBody = Data("{\"session_id\":\"s\",\"cwd\":\"/a/b\",\"tool_name\":\"Bash\"}".utf8)

        let task = Task { try await URLSession.shared.data(for: req) }

        // Give the server a moment to register the pending future.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(server.pendingCount == 1)
        let pendingId = server.pendingIDs.first!
        server.resolvePending(id: pendingId, decision: .allow)

        let (data, response) = try await task.value
        #expect((response as! HTTPURLResponse).statusCode == 200)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let output = parsed?["hookSpecificOutput"] as? [String: Any]
        #expect(output?["permissionDecision"] as? String == "allow")
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement HookBridgeServer.swift**

```swift
import Foundation
import Network

public enum HookBridgeAction: Sendable {
    case ignore
    case pendingApproval(id: UUID, payload: PreToolUsePayload)
    case fireAndForget(HookEvent, payload: Data)
}

public actor HookBridgeServer {
    public enum ServerError: Error { case notStarted, portUnknown, alreadyStarted }

    public let token: String
    private let queue: DispatchQueue = .init(label: "hookbridge.server")
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var port: UInt16?
    private var pending: [UUID: CheckedContinuation<HookEvent.PermissionDecisionKind, Never>] = [:]
    private var pendingPayloads: [UUID: PreToolUsePayload] = [:]

    /// Called when an incoming request needs app-side routing. The callback runs on the server's queue.
    /// For PreToolUse, returning `.pendingApproval(id:payload:)` causes the server to await `resolvePending`.
    private let router: @Sendable (_ event: HookEvent, _ body: Data) -> HookBridgeAction

    public init(
        token: String,
        router: @escaping @Sendable (HookEvent, Data) -> HookBridgeAction
    ) {
        self.token = token
        self.router = router
    }

    @discardableResult
    public func start() async throws -> UInt16 {
        if listener != nil { throw ServerError.alreadyStarted }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: .any)
        let l = try NWListener(using: params)
        self.listener = l

        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: self?.queue ?? .main)
            Task { await self?.handle(conn) }
        }

        let port: UInt16 = try await withCheckedThrowingContinuation { cont in
            l.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let p = l.port?.rawValue {
                        cont.resume(returning: p)
                    } else {
                        cont.resume(throwing: ServerError.portUnknown)
                    }
                case .failed(let err):
                    cont.resume(throwing: err)
                default: break
                }
            }
            l.start(queue: self.queue)
        }
        self.port = port
        return port
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        for (_, cont) in pending { cont.resume(returning: .ask) }
        pending.removeAll()
        pendingPayloads.removeAll()
    }

    public var currentPort: UInt16? { port }
    public var pendingCount: Int { pending.count }
    public var pendingIDs: [UUID] { Array(pending.keys) }
    public func pendingPayload(id: UUID) -> PreToolUsePayload? { pendingPayloads[id] }

    public func resolvePending(id: UUID, decision: HookEvent.PermissionDecisionKind) {
        guard let cont = pending.removeValue(forKey: id) else { return }
        pendingPayloads.removeValue(forKey: id)
        cont.resume(returning: decision)
    }

    /// Expire every pending approval (used when server stops or a test needs to cancel).
    public func cancelAllPending() {
        for (_, cont) in pending { cont.resume(returning: .ask) }
        pending.removeAll()
        pendingPayloads.removeAll()
    }

    // MARK: - Connection handling

    private func handle(_ conn: NWConnection) async {
        connections.append(conn)
        let request = await HookHTTPReader.read(connection: conn)
        guard let request else {
            await send(conn, status: 400, body: Data())
            return
        }

        switch (request.method, request.path) {
        case ("GET", "/health"):
            let body = try? JSONSerialization.data(withJSONObject: [
                "name": "OpenVibbleDesktop",
                "version": "0.2.0",
                "ready": true
            ], options: [.sortedKeys])
            await send(conn, status: 200, contentType: "application/json", body: body ?? Data())

        case ("POST", "/pretooluse"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            await handlePreToolUse(conn: conn, body: request.body)

        case ("POST", "/prompt"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.userPromptSubmit, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/stop"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.stop, request.body)
            await send(conn, status: 204, body: Data())

        case ("POST", "/notification"):
            guard verifyToken(request) else { await send(conn, status: 401, body: Data()); return }
            _ = router(.notification, request.body)
            await send(conn, status: 204, body: Data())

        default:
            await send(conn, status: 404, body: Data())
        }
    }

    private func handlePreToolUse(conn: NWConnection, body: Data) async {
        let action = router(.preToolUse, body)
        switch action {
        case .pendingApproval(let id, let payload):
            pendingPayloads[id] = payload
            let decision: HookEvent.PermissionDecisionKind = await withCheckedContinuation { cont in
                self.pending[id] = cont
            }
            let responseBody = Self.encodePreToolUseResponse(decision: decision)
            await send(conn, status: 200, contentType: "application/json", body: responseBody)
        case .ignore, .fireAndForget:
            let fallback = Self.encodePreToolUseResponse(decision: .ask)
            await send(conn, status: 200, contentType: "application/json", body: fallback)
        }
    }

    private static func encodePreToolUseResponse(decision: HookEvent.PermissionDecisionKind) -> Data {
        var output: [String: Any] = [
            "hookEventName": "PreToolUse",
            "permissionDecision": decision.rawValue
        ]
        if decision == .deny { output["permissionDecisionReason"] = "Denied from OpenVibbleDesktop" }
        let payload: [String: Any] = ["hookSpecificOutput": output]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    }

    private func verifyToken(_ req: HookHTTPRequest) -> Bool {
        req.headers["x-ovd-token"] == token
    }

    private func send(_ conn: NWConnection, status: Int, contentType: String = "text/plain", body: Data) async {
        let statusText = Self.statusText(status)
        var head = "HTTP/1.1 \(status) \(statusText)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(body)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            conn.send(content: data, completion: .contentProcessed { _ in
                conn.cancel()
                cont.resume()
            })
        }
    }

    private static func statusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        default: return "Status"
        }
    }
}

struct HookHTTPRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

enum HookHTTPReader {
    static func read(connection: NWConnection) async -> HookHTTPRequest? {
        var accumulated = Data()
        while true {
            let chunk: Data? = await withCheckedContinuation { (cont: CheckedContinuation<Data?, Never>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, _ in
                    if let data, !data.isEmpty {
                        cont.resume(returning: data)
                    } else if isComplete {
                        cont.resume(returning: nil)
                    } else {
                        cont.resume(returning: Data())
                    }
                }
            }
            guard let chunk else { return parse(accumulated) }
            accumulated.append(chunk)
            if let parsed = parse(accumulated), parsed.body.count >= expectedBodyLength(accumulated) {
                return parsed
            }
        }
    }

    private static func expectedBodyLength(_ data: Data) -> Int {
        guard let headEnd = range(of: "\r\n\r\n", in: data) else { return 0 }
        let head = data.subdata(in: 0..<headEnd.lowerBound)
        guard let headStr = String(data: head, encoding: .utf8) else { return 0 }
        for line in headStr.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                return Int(parts[1]) ?? 0
            }
        }
        return 0
    }

    private static func parse(_ data: Data) -> HookHTTPRequest? {
        guard let headEnd = range(of: "\r\n\r\n", in: data) else { return nil }
        let head = data.subdata(in: 0..<headEnd.lowerBound)
        let body = data.subdata(in: headEnd.upperBound..<data.count)
        guard let headStr = String(data: head, encoding: .utf8) else { return nil }
        let lines = headStr.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2 { headers[kv[0].lowercased()] = kv[1] }
        }
        let expected = Int(headers["content-length"] ?? "0") ?? 0
        let trimmedBody = body.count >= expected ? body.subdata(in: 0..<expected) : body
        return HookHTTPRequest(method: method, path: path, headers: headers, body: trimmedBody)
    }

    private static func range(of needle: String, in data: Data) -> Range<Data.Index>? {
        let needleBytes = Data(needle.utf8)
        return data.range(of: needleBytes)
    }
}
```

Note: this is an actor, so `pendingCount` / `pendingIDs` / `resolvePending` / `pendingPayload(id:)` are `async` from outside. Update the test to `await` them:

```swift
#expect(await server.pendingCount == 1)
let pendingId = (await server.pendingIDs).first!
await server.resolvePending(id: pendingId, decision: .allow)
```

- [ ] **Step 4: Run — expect PASS**

```bash
cd Packages/OpenVibbleKit && swift test --filter HookBridgeServerTests
```

Watch for `NWListener` port-allocation / cleanup race — tests run sequentially, each creates its own server on port 0.

- [ ] **Step 5: Commit**

```bash
git add Packages/OpenVibbleKit
git commit -m "Add HookBridgeServer HTTP service with pending-approval race"
```

---

## Task 6.5 — Extend `NUSCentral` to parse inbound `PermissionCommand`

**Files:**
- Modify: `Packages/OpenVibbleKit/Sources/NUSCentral/CentralInboundMessage.swift`
- Modify: `Packages/OpenVibbleKit/Tests/NUSCentralTests/*.swift` (add test)

iOS sends `PermissionCommand` (`cmd:"permission"`) via TX notify when the user taps Approve/Deny. Currently `CentralInboundMessage` only decodes heartbeat / turn / ack / timeSync — the decision is silently dropped into `.unknown`.

- [ ] **Step 1: Write failing test**

Append to `Packages/OpenVibbleKit/Tests/NUSCentralTests/` (create a new file `PermissionInboundTests.swift`):

```swift
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
```

- [ ] **Step 2: Run — expect FAIL (no `.permission` case yet)**

```bash
cd Packages/OpenVibbleKit && swift test --filter PermissionInboundTests
```

- [ ] **Step 3: Extend enum and decoder**

Replace `Packages/OpenVibbleKit/Sources/NUSCentral/CentralInboundMessage.swift`:

```swift
import Foundation
import BuddyProtocol

public enum CentralInboundMessage: Equatable, Sendable {
    case heartbeat(HeartbeatSnapshot)
    case turn(TurnEvent)
    case timeSync(TimeSync)
    case ack(BridgeAck)
    case permission(PermissionCommand)
    case unknown(String)
}

public enum CentralInboundDecoder {
    public static func decode(_ line: String) -> CentralInboundMessage {
        let data = Data(line.utf8)
        let decoder = JSONDecoder()

        if let ack = try? decoder.decode(BridgeAck.self, from: data), !ack.ack.isEmpty {
            return .ack(ack)
        }
        if let turn = try? decoder.decode(TurnEvent.self, from: data), turn.evt == "turn" {
            return .turn(turn)
        }
        if let cmd = try? decoder.decode(PermissionCommand.self, from: data), cmd.cmd == "permission" {
            return .permission(cmd)
        }
        if let heartbeat = try? decoder.decode(HeartbeatSnapshot.self, from: data) {
            return .heartbeat(heartbeat)
        }
        if let time = try? decoder.decode(TimeSync.self, from: data) {
            return .timeSync(time)
        }
        return .unknown(line)
    }
}
```

(`PermissionCommand` is already public in `BuddyProtocol/BridgeModels.swift`.)

- [ ] **Step 4: Run all tests — expect PASS**

```bash
cd Packages/OpenVibbleKit && swift test
```

- [ ] **Step 5: Commit**

```bash
git add Packages/OpenVibbleKit/Sources/NUSCentral Packages/OpenVibbleKit/Tests/NUSCentralTests
git commit -m "Parse inbound PermissionCommand in NUSCentral decoder"
```

---

## Task 7 — Remove app sandbox from OpenVibbleDesktop

**Files:**
- Modify: `OpenVibbleDesktop/OpenVibbleDesktop.entitlements`

- [ ] **Step 1: Replace entitlements content**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

(Drop `app-sandbox` + `device.bluetooth`; sandbox off means the bluetooth entitlement is unnecessary.)

- [ ] **Step 2: Regenerate project and build**

```bash
cd path/to/claude-buddy-bridge-ios
xcodegen
xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add OpenVibbleDesktop/OpenVibbleDesktop.entitlements
git commit -m "Disable App Sandbox on OpenVibbleDesktop for ~/.claude access"
```

---

## Task 8 — Wire `HookBridge` into `project.yml` and Desktop target

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add HookBridge dependency**

In `project.yml` under `targets.OpenVibbleDesktop.dependencies`, append:

```yaml
      - package: OpenVibbleKit
        product: HookBridge
```

- [ ] **Step 2: Regenerate + build**

```bash
xcodegen
xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED` (no source changes yet; just dependency wired).

- [ ] **Step 3: Commit**

```bash
git add project.yml
git commit -m "Link HookBridge into OpenVibbleDesktop target"
```

---

## Task 9 — `AppState` integration

**Files:**
- Modify: `OpenVibbleDesktop/AppState.swift`

Add state for pending approval, hook activity, registration status. Own the `HookBridgeServer` + `HookRegistrar`, start the server on init, stop on deinit.

- [ ] **Step 1: Add imports and stored properties**

At top of `AppState.swift`, add import:

```swift
import HookBridge
```

Inside the class, just after the other `@Published` properties (around line 38):

```swift
    @Published var pendingApproval: PendingApprovalState?
    @Published var hookActivity = HookActivityLog(capacity: 50)
    @Published var registrationStatus: HookRegistrationStatus = .notRegistered
    @Published var bridgeReady: Bool = false
    @Published var bridgePort: UInt16?

    private let registrar = HookRegistrar(
        settingsURL: HookRegistrar.defaultSettingsURL(),
        portFilePath: "$HOME/.claude/openvibble.port"
    )
    private let portFileStore = PortFileStore(url: PortFileStore.defaultURL())
    private var bridgeServer: HookBridgeServer?
    private var bridgeStartTask: Task<Void, Never>?

    public struct PendingApprovalState: Equatable, Identifiable {
        public let id: UUID
        public let projectName: String?
        public let toolName: String?
        public let hint: String?
        public let payload: PreToolUsePayload
    }
```

- [ ] **Step 2: Start bridge in `init`**

At the end of `init()`, add:

```swift
        refreshRegistrationStatus()
        startBridge()
```

Add methods:

```swift
    private func startBridge() {
        let token = Self.generateToken()
        let server = HookBridgeServer(token: token) { [weak self] event, body in
            switch event {
            case .preToolUse:
                let payload = (try? JSONDecoder().decode(PreToolUsePayload.self, from: body)) ?? PreToolUsePayload.empty
                let id = UUID()
                Task { @MainActor [weak self] in
                    self?.pushPending(id: id, payload: payload)
                }
                return .pendingApproval(id: id, payload: payload)
            default:
                Task { @MainActor [weak self] in
                    self?.recordFireAndForget(event: event, body: body)
                }
                return .ignore
            }
        }
        self.bridgeServer = server
        bridgeStartTask = Task { [weak self] in
            do {
                let port = try await server.start()
                let payload = PortFile(port: Int(port), token: token, pid: Int(ProcessInfo.processInfo.processIdentifier), version: 1)
                try self?.portFileStore.write(payload)
                await MainActor.run {
                    self?.bridgePort = port
                    self?.bridgeReady = true
                    self?.appendLog("[bridge] listening on 127.0.0.1:\(port)")
                }
            } catch {
                await MainActor.run {
                    self?.appendLog("[bridge] start failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    func stopBridge() {
        bridgeStartTask?.cancel()
        Task { [bridgeServer, portFileStore] in
            await bridgeServer?.stop()
            try? portFileStore.remove()
        }
    }

    deinit { stopBridge() }
```

- [ ] **Step 3: Implement pending/decision + fire-and-forget plumbing**

Add methods:

```swift
    private func pushPending(id: UUID, payload: PreToolUsePayload) {
        let project = HookEvent.projectName(fromCwd: payload.cwd)
        let hint = (payload.toolInput?["command"]
            ?? payload.toolInput?["description"]
            ?? payload.toolInput?["file_path"]).map { String($0.prefix(120)) }
        let state = PendingApprovalState(
            id: id,
            projectName: project,
            toolName: payload.toolName,
            hint: hint,
            payload: payload
        )
        self.pendingApproval = state
        appendLog("[hook] PreToolUse \(payload.toolName ?? "?") [\(project ?? "?")]")
        hookActivity.append(HookActivityEntry(
            event: .preToolUse,
            projectName: project,
            toolName: payload.toolName
        ))
        pushPromptToPeripheral(state)
    }

    /// Synthesize a HeartbeatSnapshot whose `prompt` carries the new pending approval
    /// and write it to iOS's RX characteristic. iOS's BridgeRuntime.ingestLine picks up
    /// `heartbeat.prompt` and renders the permission dialog.
    private func pushPromptToPeripheral(_ pending: PendingApprovalState?) {
        let base = heartbeat
        let promptInfo: HeartbeatPrompt? = pending.map { p in
            let label = p.hint ?? p.toolName ?? "request"
            let hint = p.projectName.map { "[\($0)] \(label)" } ?? label
            return HeartbeatPrompt(id: p.id.uuidString, tool: p.toolName, hint: hint)
        }
        let snapshot = HeartbeatSnapshot(
            total: base?.total ?? 0,
            running: base?.running ?? 0,
            waiting: (base?.waiting ?? 0) + (promptInfo == nil ? 0 : 1),
            msg: promptInfo == nil ? "cleared" : "pending",
            entries: base?.entries ?? [],
            tokens: base?.tokens,
            tokensToday: base?.tokensToday,
            prompt: promptInfo,
            completed: false
        )
        _ = central.sendEncodable(snapshot)
    }

    private func recordFireAndForget(event: HookEvent, body: Data) {
        let projectName = Self.extractCwd(from: body).flatMap { HookEvent.projectName(fromCwd: $0) }
        hookActivity.append(HookActivityEntry(event: event, projectName: projectName))
        appendLog("[hook] \(event.rawValue) [\(projectName ?? "?")]")
    }

    private static func extractCwd(from body: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        return obj["cwd"] as? String
    }

    func approvePending() {
        guard let pending = pendingApproval else { return }
        resolve(pending: pending, decision: .allow)
    }

    func denyPending() {
        guard let pending = pendingApproval else { return }
        resolve(pending: pending, decision: .deny)
    }

    private func resolve(pending: PendingApprovalState, decision: HookEvent.PermissionDecisionKind) {
        guard let server = bridgeServer else { return }
        Task { await server.resolvePending(id: pending.id, decision: decision) }
        self.pendingApproval = nil
        hookActivity.append(HookActivityEntry(
            event: .preToolUse,
            projectName: pending.projectName,
            toolName: pending.toolName,
            decision: decision
        ))
        // Clear the prompt on iOS by pushing a heartbeat with prompt=nil.
        pushPromptToPeripheral(nil)
        appendLog("[hook] decide \(decision.rawValue) id=\(pending.id)")
    }

    func registerHooks() {
        do {
            try registrar.register()
            refreshRegistrationStatus()
            appendLog("[hook] registered")
        } catch {
            appendLog("[hook] register failed: \(error.localizedDescription)")
        }
    }

    func unregisterHooks() {
        do {
            try registrar.unregister()
            refreshRegistrationStatus()
            appendLog("[hook] unregistered")
        } catch {
            appendLog("[hook] unregister failed: \(error.localizedDescription)")
        }
    }

    func refreshRegistrationStatus() {
        do { registrationStatus = try registrar.status() }
        catch { registrationStatus = .notRegistered }
    }
```

Also **extend the existing `ingest(_:)` switch** (around line 188 of current AppState.swift) to route inbound `.permission` decisions to the race:

```swift
    private func ingest(_ message: CentralInboundMessage) {
        switch message {
        case .heartbeat(let snapshot):
            heartbeat = snapshot
            appendLog("[recv] heartbeat total=\(snapshot.total) running=\(snapshot.running) waiting=\(snapshot.waiting)")
        case .turn(let turn):
            lastTurn = turn
            appendLog("[recv] turn role=\(turn.role)")
        case .timeSync(let time):
            lastTimeSync = time
            appendLog("[recv] time epoch=\(time.epochSeconds) tz=\(time.timezoneOffsetSeconds)")
        case .ack(let ack):
            lastAck = ack
            if ack.ack == "status", let payload = ack.data {
                statusSnapshot = parseStatus(payload)
            }
            appendLog("[recv] ack=\(ack.ack) ok=\(ack.ok) err=\(ack.error ?? "-")")
        case .permission(let command):
            appendLog("[recv] permission id=\(command.id) decision=\(command.decision.rawValue)")
            guard let pending = pendingApproval, pending.id.uuidString == command.id else { return }
            let kind: HookEvent.PermissionDecisionKind = command.decision == .once ? .allow : .deny
            resolve(pending: pending, decision: kind)
        case .unknown(let raw):
            appendLog("[recv] unknown \(raw.prefix(120))")
        }
    }
```

Extend `PreToolUsePayload` with an empty stub used when decoding fails — add this at the bottom of AppState.swift file (outside the class):

```swift
extension PreToolUsePayload {
    static let empty = PreToolUsePayload(
        sessionId: nil, cwd: nil, toolName: nil, toolInput: nil, transcriptPath: nil
    )

    init(sessionId: String?, cwd: String?, toolName: String?, toolInput: [String: String]?, transcriptPath: String?) {
        self.sessionId = sessionId; self.cwd = cwd; self.toolName = toolName
        self.toolInput = toolInput; self.transcriptPath = transcriptPath
    }
}
```

(This requires changing `PreToolUsePayload`'s stored properties from `let` + `Decodable`-only to `var`; easier to make them all `public let` — open the HookBridge source and add a public memberwise init. See fix-up step below.)

- [ ] **Step 4: Add memberwise init to `PreToolUsePayload`**

In `Packages/OpenVibbleKit/Sources/HookBridge/HookEvent.swift`, change struct to:

```swift
public struct PreToolUsePayload: Codable, Sendable {
    public let sessionId: String?
    public let cwd: String?
    public let toolName: String?
    public let toolInput: [String: String]?
    public let transcriptPath: String?

    public init(
        sessionId: String?,
        cwd: String?,
        toolName: String?,
        toolInput: [String: String]?,
        transcriptPath: String?
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.toolName = toolName
        self.toolInput = toolInput
        self.transcriptPath = transcriptPath
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case transcriptPath = "transcript_path"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionId = try? c.decode(String.self, forKey: .sessionId)
        self.cwd = try? c.decode(String.self, forKey: .cwd)
        self.toolName = try? c.decode(String.self, forKey: .toolName)
        self.transcriptPath = try? c.decode(String.self, forKey: .transcriptPath)
        if let raw = try? c.decode([String: AnyCodable].self, forKey: .toolInput) {
            var flat: [String: String] = [:]
            for (k, v) in raw { flat[k] = v.stringified }
            self.toolInput = flat
        } else {
            self.toolInput = nil
        }
    }
}
```

Drop the duplicate init from `AppState.swift` (keep only the `empty` static stub).

- [ ] **Step 5: Build**

```bash
xcodegen
xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add OpenVibbleDesktop/AppState.swift Packages/OpenVibbleKit
git commit -m "Wire HookBridgeServer + HookRegistrar into AppState"
```

---

## Task 10 — New localization keys (en + zh-Hans)

**Files:**
- Modify: `OpenVibbleDesktop/Resources/Localizable.xcstrings`

Keys to add (see spec §本地化). Use Xcode's string catalog editor, or directly edit the JSON.

- [ ] **Step 1: Add keys via JSON edit**

For each key below, add a `strings` entry with `localizations: {en: {...}, zh-Hans: {...}}`. Template:

```json
"desktop.tab.overview" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Overview" } },
    "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "概览" } }
  }
}
```

Full key list (en → zh-Hans):
- `desktop.tab.overview` — "Overview" / "概览"
- `desktop.tab.hooks` — "Hooks" / "钩子"
- `desktop.tab.testPanel` — "Test Panel" / "测试面板"
- `desktop.tab.bridge` — "Bridge API" / "桥接说明"
- `desktop.tab.settings` — "Settings" / "设置"
- `desktop.hooks.status.registered` — "Registered" / "已注册"
- `desktop.hooks.status.partial` — "Partially registered" / "部分注册"
- `desktop.hooks.status.notRegistered` — "Not registered" / "未注册"
- `desktop.hooks.register` — "Register hooks" / "注册 hooks"
- `desktop.hooks.unregister` — "Unregister" / "注销"
- `desktop.hooks.preToolUse.title` — "PreToolUse" / "工具调用前"
- `desktop.hooks.preToolUse.desc` — "Before Claude Code runs a tool. Blocks up to 30s waiting for your approval." / "Claude Code 执行工具前触发。最多阻塞 30 秒等待你的决策。"
- `desktop.hooks.userPromptSubmit.title` — "UserPromptSubmit" / "用户提交"
- `desktop.hooks.userPromptSubmit.desc` — "Fires when you send a message to Claude Code." / "你向 Claude Code 发消息时触发。"
- `desktop.hooks.stop.title` — "Stop" / "回合结束"
- `desktop.hooks.stop.desc` — "Fires when Claude Code finishes a response." / "Claude Code 完成一次回复时触发。"
- `desktop.hooks.notification.title` — "Notification" / "系统通知"
- `desktop.hooks.notification.desc` — "Claude Code system-level notifications." / "Claude Code 系统级通知事件。"
- `desktop.hooks.lastFired` — "Last fired %@" / "上次触发 %@"
- `desktop.hooks.todayCount` — "Today: %d" / "今日：%d"
- `desktop.hooks.petState` — "Pet: %@" / "宠物：%@"
- `desktop.hooks.bleAction` — "BLE: %@" / "蓝牙：%@"
- `desktop.hooks.empty` — "No activity yet" / "暂无活动"
- `desktop.pending.title` — "Waiting for approval" / "等待审批"
- `desktop.pending.project` — "Project: %@" / "项目：%@"
- `desktop.pending.tool` — "Tool: %@" / "工具：%@"
- `desktop.bridge.intro` — "OpenVibbleDesktop bridges local HTTP events to the iOS buddy over Bluetooth. Any agent that can POST JSON to localhost can integrate." / "OpenVibbleDesktop 通过本地 HTTP 把事件桥接到蓝牙桌宠。任何能向本机 POST JSON 的 agent 都可接入。"
- `desktop.bridge.baseUrl` — "Base URL" / "基础 URL"
- `desktop.bridge.token` — "Token" / "令牌"
- `desktop.bridge.portFile` — "Port file" / "端口文件"
- `desktop.bridge.endpoints` — "Endpoints" / "端点"
- `desktop.bridge.exampleCurl` — "Example curl" / "curl 示例"
- `desktop.bridge.copy` — "Copy" / "复制"
- `desktop.bridge.copied` — "Copied" / "已复制"
- `desktop.bridge.notReady` — "Bridge not ready" / "桥接未就绪"
- `desktop.settings.language` — "Language" / "语言"
- `desktop.settings.about` — "About" / "关于"
- `desktop.overview.petState` — "Pet state" / "宠物状态"
- `desktop.overview.recentHooks` — "Recent hook events" / "最近 hook 事件"

- [ ] **Step 2: Build and confirm catalog compiles**

```bash
xcodegen
xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED` and lproj folders in `.app/Contents/Resources/`.

- [ ] **Step 3: Commit**

```bash
git add OpenVibbleDesktop/Resources/Localizable.xcstrings
git commit -m "Add localization keys for hook bridge UI"
```

---

## Task 11 — Restructure `MainView` into TabView shell + move old content to `TestPanelTab`

**Files:**
- Modify: `OpenVibbleDesktop/Views/MainView.swift`
- Create: `OpenVibbleDesktop/Views/Tabs/TestPanelTab.swift`

- [ ] **Step 1: Create TestPanelTab with the existing sections**

Create `OpenVibbleDesktop/Views/Tabs/TestPanelTab.swift`. Copy the `deviceSection` / `batterySection` / `statsSection` / `systemSection` / `pendingSection` (rename to `legacyPendingSection`) / `manualSection` / `speciesSection` / `installSection` / `logSection` from the current `MainView.swift`, plus the helpers (`infoRow`, `pickFolder`, `formatUptime`, `isConnected`). Strip the header/languagePicker — those move to SettingsTab.

```swift
import SwiftUI
import AppKit
import BuddyProtocol
import BuddyPersona

struct TestPanelTab: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var l10n = LocalizationManager.shared
    @State private var nameDraft = "Claude-iOS"
    @State private var ownerDraft = "Felix"
    @State private var packNameDraft = ""
    @State private var speciesSelection: Int = 4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                deviceSection
                batterySection
                statsSection
                systemSection
                legacyPendingSection
                manualSection
                speciesSection
                installSection
                logSection
            }
            .padding(16)
        }
    }

    // ... copy all the private var section properties and helpers here,
    //     removing `header`, `languagePicker`, `showScanSheet`-related bits.
}
```

(Direct copy from `MainView.swift:93-301` except for the `header`/`languagePicker` and `isConnected` stays.)

- [ ] **Step 2: Rewrite MainView as TabView shell**

Replace `OpenVibbleDesktop/Views/MainView.swift` content with:

```swift
import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    @State private var selection: Tab = .overview
    @State private var showScanSheet = false

    enum Tab: Hashable { case overview, hooks, testPanel, bridge, settings }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showScanSheet: $showScanSheet)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            TabView(selection: $selection) {
                OverviewTab()
                    .tabItem { Label { LText("desktop.tab.overview") } icon: { Image(systemName: "gauge") } }
                    .tag(Tab.overview)
                HooksTab()
                    .tabItem { Label { LText("desktop.tab.hooks") } icon: { Image(systemName: "link") } }
                    .tag(Tab.hooks)
                TestPanelTab()
                    .tabItem { Label { LText("desktop.tab.testPanel") } icon: { Image(systemName: "wrench.and.screwdriver") } }
                    .tag(Tab.testPanel)
                BridgeDocsTab()
                    .tabItem { Label { LText("desktop.tab.bridge") } icon: { Image(systemName: "doc.plaintext") } }
                    .tag(Tab.bridge)
                SettingsTab()
                    .tabItem { Label { LText("desktop.tab.settings") } icon: { Image(systemName: "gearshape") } }
                    .tag(Tab.settings)
            }
        }
        .environment(\.localizationBundle, l10n.bundle)
        .sheet(isPresented: $showScanSheet) {
            ScanSheet().environmentObject(state).environment(\.localizationBundle, l10n.bundle)
        }
    }
}

private struct TopBar: View {
    @EnvironmentObject var state: AppState
    @Binding var showScanSheet: Bool
    @ObservedObject var l10n = LocalizationManager.shared
    @Environment(\.openWindow) var openWindow

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(indicator).frame(width: 10, height: 10)
            Text(label).font(.headline)
            Spacer()
            Button(action: { openWindow(id: "about") }) {
                Label { LText("desktop.about") } icon: { Image(systemName: "info.circle") }
            }
            if isConnected {
                Button(action: { state.disconnect() }) { LText("desktop.btn.disconnect") }
            } else {
                Button(action: { state.startScan(); showScanSheet = true }) { LText("desktop.btn.connect") }
            }
        }
    }

    private var isConnected: Bool { if case .connected = state.connection { true } else { false } }

    private var label: String {
        switch state.connection {
        case .connected: return l10n.bundle.l("desktop.menu.summary.connected", state.connectedName ?? l10n.bundle.l("desktop.value.none"))
        case .scanning: return l10n.bundle.l("desktop.header.scanning")
        case .connecting: return l10n.bundle.l("desktop.header.connecting")
        case .disconnecting: return l10n.bundle.l("desktop.header.disconnecting")
        case .idle: return l10n.bundle.l("desktop.header.idle")
        case .poweredOff: return state.bluetoothNote
        case .unauthorized: return l10n.bundle.l("desktop.header.unauth")
        case .unsupported: return l10n.bundle.l("desktop.header.unsupported")
        case .unknown: return l10n.bundle.l("desktop.header.startup")
        case .error(let m): return l10n.bundle.l("desktop.header.error", m)
        }
    }

    private var indicator: Color {
        switch state.connection {
        case .connected: return .blue
        case .scanning, .connecting: return .orange
        case .error, .poweredOff, .unauthorized, .unsupported: return .red
        default: return .gray
        }
    }
}
```

- [ ] **Step 3: Temporary stubs for the other 4 tabs**

So the project still compiles before later tasks add them, create placeholder stubs:

```bash
mkdir -p OpenVibbleDesktop/Views/Tabs
```

Create `OpenVibbleDesktop/Views/Tabs/OverviewTab.swift`, `HooksTab.swift`, `BridgeDocsTab.swift`, `SettingsTab.swift` — each:

```swift
import SwiftUI
struct OverviewTab: View { var body: some View { Text("Overview — coming soon").padding() } }
// (analogous Hooks / BridgeDocs / Settings stubs)
```

- [ ] **Step 4: Build and run app**

```bash
xcodegen
xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`. Launch the app via Xcode or `open build/Build/Products/Debug/OpenVibbleDesktop.app` — confirm 5 tabs visible; Test Panel tab shows all old content.

- [ ] **Step 5: Commit**

```bash
git add OpenVibbleDesktop/Views/MainView.swift OpenVibbleDesktop/Views/Tabs
git commit -m "Split MainView into TabView shell with Test Panel migration"
```

---

## Task 12 — `PendingApprovalBanner` + `OverviewTab`

**Files:**
- Create: `OpenVibbleDesktop/Views/PendingApprovalBanner.swift`
- Modify (rewrite stub): `OpenVibbleDesktop/Views/Tabs/OverviewTab.swift`

- [ ] **Step 1: Implement PendingApprovalBanner**

```swift
import SwiftUI
import HookBridge

struct PendingApprovalBanner: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if let pending = state.pendingApproval {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    LText("desktop.pending.title").font(.headline)
                    Spacer()
                }
                if let project = pending.projectName {
                    Text(String(format: l("desktop.pending.project"), project))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let tool = pending.toolName {
                    Text(String(format: l("desktop.pending.tool"), tool))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let hint = pending.hint {
                    Text(hint)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                HStack {
                    Button(action: { state.approvePending() }) { LText("desktop.btn.approve") }
                        .tint(.green).keyboardShortcut(.return)
                    Button(action: { state.denyPending() }) { LText("desktop.btn.deny") }
                        .tint(.red)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @Environment(\.localizationBundle) private var bundle
    private func l(_ key: String) -> String { bundle.l(key) }
}
```

- [ ] **Step 2: Implement OverviewTab**

```swift
import SwiftUI
import HookBridge

struct OverviewTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PendingApprovalBanner()

                GroupBox(label: LText("desktop.device")) {
                    VStack(alignment: .leading, spacing: 6) {
                        row("desktop.device.name", state.connectedName ?? "—")
                        let snap = state.statusSnapshot
                        row("desktop.battery.pct", snap.batteryPct.map { "\($0)%" } ?? "—")
                        row("desktop.stats.level", snap.statsLevel.map(String.init) ?? "—")
                        row("desktop.stats.approved", snap.statsApproved.map(String.init) ?? "—")
                    }
                }

                GroupBox(label: LText("desktop.overview.recentHooks")) {
                    if state.hookActivity.recent.isEmpty {
                        LText("desktop.hooks.empty").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(state.hookActivity.recent.prefix(5)) { entry in
                                HStack {
                                    Text(entry.event.rawValue).font(.caption.weight(.semibold))
                                    if let p = entry.projectName { Text("[\(p)]").font(.caption).foregroundStyle(.secondary) }
                                    Spacer()
                                    Text(relative(entry.firedAt)).font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            LText(key).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
        }
    }

    private func relative(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
```

- [ ] **Step 3: Build + launch**

```bash
xcodegen && xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`. Manual check: Overview tab renders; banner hidden when no pending.

- [ ] **Step 4: Commit**

```bash
git add OpenVibbleDesktop/Views
git commit -m "Add PendingApprovalBanner and Overview tab"
```

---

## Task 13 — `HooksTab` with `EventCard`

**Files:**
- Create: `OpenVibbleDesktop/Views/EventCard.swift`
- Modify: `OpenVibbleDesktop/Views/Tabs/HooksTab.swift`

- [ ] **Step 1: EventCard view**

```swift
import SwiftUI
import HookBridge

struct EventCard: View {
    let event: HookEvent
    let titleKey: String
    let descKey: String
    let stats: HookEventStats

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                LText(titleKey).font(.headline)
                Spacer()
            }
            LText(descKey).font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack(spacing: 12) {
                Label { Text(String(format: l("desktop.hooks.todayCount"), stats.todayCount)) }
                    icon: { Image(systemName: "number.square") }
                    .font(.caption)
                if let last = stats.lastFired {
                    Label { Text(String(format: l("desktop.hooks.lastFired"), RelativeDateTimeFormatter().localizedString(for: last, relativeTo: Date()))) }
                        icon: { Image(systemName: "clock") }
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch event {
        case .preToolUse: return "shield"
        case .userPromptSubmit: return "text.bubble"
        case .stop: return "checkmark.seal"
        case .notification: return "bell"
        }
    }

    @Environment(\.localizationBundle) private var bundle
    private func l(_ key: String) -> String { bundle.l(key) }
}
```

- [ ] **Step 2: HooksTab**

```swift
import SwiftUI
import HookBridge

struct HooksTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusHeader

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    EventCard(event: .preToolUse, titleKey: "desktop.hooks.preToolUse.title", descKey: "desktop.hooks.preToolUse.desc", stats: state.hookActivity.stats(for: .preToolUse))
                    EventCard(event: .userPromptSubmit, titleKey: "desktop.hooks.userPromptSubmit.title", descKey: "desktop.hooks.userPromptSubmit.desc", stats: state.hookActivity.stats(for: .userPromptSubmit))
                    EventCard(event: .stop, titleKey: "desktop.hooks.stop.title", descKey: "desktop.hooks.stop.desc", stats: state.hookActivity.stats(for: .stop))
                    EventCard(event: .notification, titleKey: "desktop.hooks.notification.title", descKey: "desktop.hooks.notification.desc", stats: state.hookActivity.stats(for: .notification))
                }

                GroupBox(label: LText("desktop.hooks.empty")) {
                    if state.hookActivity.recent.isEmpty {
                        LText("desktop.hooks.empty").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(state.hookActivity.recent.prefix(20)) { entry in
                                HStack(spacing: 8) {
                                    Text(entry.event.rawValue).font(.caption.monospaced())
                                    if let project = entry.projectName { Text("[\(project)]").font(.caption).foregroundStyle(.secondary) }
                                    if let tool = entry.toolName { Text(tool).font(.caption).foregroundStyle(.secondary) }
                                    if let decision = entry.decision { Text(decision.rawValue).font(.caption.bold()).foregroundStyle(color(decision)) }
                                    Spacer()
                                    Text(entry.firedAt, style: .time).font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var statusHeader: some View {
        HStack {
            switch state.registrationStatus {
            case .registered:
                Label { LText("desktop.hooks.status.registered") } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
            case .partiallyRegistered:
                Label { LText("desktop.hooks.status.partial") } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
            case .notRegistered:
                Label { LText("desktop.hooks.status.notRegistered") } icon: { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }
            Spacer()
            if isRegistered {
                Button(action: { state.unregisterHooks() }) { LText("desktop.hooks.unregister") }
            } else {
                Button(action: { state.registerHooks() }) { LText("desktop.hooks.register") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 4)
    }

    private var isRegistered: Bool {
        if case .notRegistered = state.registrationStatus { return false }
        return true
    }

    private func color(_ d: HookEvent.PermissionDecisionKind) -> Color {
        switch d { case .allow: .green; case .deny: .red; case .ask: .orange }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodegen && xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

- [ ] **Step 4: Commit**

```bash
git add OpenVibbleDesktop/Views
git commit -m "Add Hooks tab with EventCard and registration controls"
```

---

## Task 14 — `BridgeDocsTab`

**Files:**
- Modify: `OpenVibbleDesktop/Views/Tabs/BridgeDocsTab.swift`

- [ ] **Step 1: Implement docs view with copy buttons**

```swift
import SwiftUI
import AppKit
import HookBridge

struct BridgeDocsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LText("desktop.bridge.intro")
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox(label: LText("desktop.bridge.baseUrl")) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let port = state.bridgePort {
                            labeled("http://127.0.0.1:\(port)")
                        } else {
                            LText("desktop.bridge.notReady").foregroundStyle(.secondary)
                        }
                        Text("~/.claude/openvibble.port").font(.caption).foregroundStyle(.secondary)
                    }
                }

                GroupBox(label: LText("desktop.bridge.endpoints")) {
                    VStack(alignment: .leading, spacing: 6) {
                        endpointRow(method: "POST", path: "/pretooluse", note: "blocking (≤30s)")
                        endpointRow(method: "POST", path: "/prompt",     note: "fire-and-forget")
                        endpointRow(method: "POST", path: "/stop",       note: "fire-and-forget")
                        endpointRow(method: "POST", path: "/notification", note: "fire-and-forget")
                        endpointRow(method: "GET",  path: "/health",     note: "unauthenticated")
                    }
                }

                GroupBox(label: LText("desktop.bridge.exampleCurl")) {
                    exampleCurl
                }

                Button(action: openRepo) {
                    Label("GitHub", systemImage: "arrow.up.right.square")
                }
            }
            .padding(16)
        }
    }

    private var exampleCurl: some View {
        let cmd = """
curl -s --max-time 30 \\
  -H "X-OVD-Token: $(jq -r .token ~/.claude/openvibble.port)" \\
  http://127.0.0.1:$(jq -r .port ~/.claude/openvibble.port)/pretooluse \\
  -d '{"session_id":"demo","cwd":"/path/to/project","tool_name":"Bash","tool_input":{"command":"ls"}}'
"""
        return HStack(alignment: .top) {
            Text(cmd).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Button(action: { copyToPasteboard(cmd) }) { LText("desktop.bridge.copy") }
                .buttonStyle(.borderless)
        }
    }

    private func endpointRow(method: String, path: String, note: String) -> some View {
        HStack {
            Text(method).font(.caption.bold()).frame(width: 50, alignment: .leading)
            Text(path).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Text(note).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func labeled(_ s: String) -> some View {
        HStack {
            Text(s).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Button(action: { copyToPasteboard(s) }) { LText("desktop.bridge.copy") }
                .buttonStyle(.borderless)
        }
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func openRepo() {
        if let url = URL(string: "https://github.com/kingcos/claude-buddy-bridge-ios") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen && xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

- [ ] **Step 3: Commit**

```bash
git add OpenVibbleDesktop/Views/Tabs/BridgeDocsTab.swift
git commit -m "Add Bridge API docs tab with endpoint reference and curl example"
```

---

## Task 15 — `SettingsTab` with language picker migration

**Files:**
- Modify: `OpenVibbleDesktop/Views/Tabs/SettingsTab.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI
import AppKit

struct SettingsTab: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox(label: LText("desktop.settings.language")) {
                    Picker(selection: Binding(
                        get: { l10n.language },
                        set: { l10n.set($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.titleKey, bundle: l10n.bundle).tag(lang)
                        }
                    } label: {
                        LText("desktop.settings.language")
                    }
                    .pickerStyle(.radioGroup)
                }

                GroupBox(label: LText("desktop.settings.about")) {
                    Button(action: { openWindow(id: "about") }) {
                        Label { LText("desktop.about") } icon: { Image(systemName: "info.circle") }
                    }
                }
            }
            .padding(16)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodegen && xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

- [ ] **Step 3: Commit**

```bash
git add OpenVibbleDesktop/Views/Tabs/SettingsTab.swift
git commit -m "Add Settings tab with language picker and about entry"
```

---

## Task 16 — End-to-end manual verification

**Files:** none changed; this task produces a verification log committed as a note at the bottom of the spec.

- [ ] **Step 1: Run all SPM tests**

```bash
cd Packages/OpenVibbleKit && swift test
```

Expected: all existing + new tests pass (HookBridge suite included).

- [ ] **Step 2: Build macOS app**

```bash
cd ..
xcodebuild -scheme OpenVibbleDesktop -destination 'platform=macOS' build
```

- [ ] **Step 3: Launch manually and smoke-test**

Open the built app (`open /path/to/OpenVibbleDesktop.app`) and verify:

1. 5 tabs visible: Overview / Hooks / Test Panel / Bridge API / Settings
2. Overview: pending banner hidden when no pending
3. Hooks: status = "Not registered"; click Register → status = "Registered"; `~/.claude/settings.json` contains 4 entries with `OVD-MANAGED-v1` markers
4. Bridge API tab: base URL shows a `127.0.0.1:PORT`; curl example present; copy buttons work
5. Settings: switch language between English / 简体中文 / 跟随系统 — all tabs update
6. `~/.claude/openvibble.port` exists with 0600 perms while app is running; deleted on quit

Then use Claude Code to trigger hooks:

```bash
# In a terminal with Claude Code installed:
claude "run: echo hello"
```

- PreToolUse fires → banner appears in Overview → click Approve → CC proceeds
- Repeat, click Deny → CC blocks tool
- Close Mac app while a new CC session is running → PreToolUse hook should fail-open (terminal Y/N appears normally)

- [ ] **Step 4: Build iOS to check zero regression**

```bash
xcodebuild -scheme OpenVibbleApp -destination 'generic/platform=iOS' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit verification summary**

Append to `docs/superpowers/specs/2026-04-22-claude-code-hook-bridging-design.md` a new section:

```markdown
## Implementation log

- 2026-04-22: Implemented per plan `docs/superpowers/plans/2026-04-22-hook-bridging-implementation.md`.
  - SPM target `HookBridge` added with 4 types + HTTP server; all tests pass.
  - OpenVibbleDesktop restructured into 5-tab window; sandbox disabled.
  - Manual end-to-end smoke test: Register / PreToolUse / Approve / Deny / Fail-open all verified.
```

```bash
git add docs/superpowers/specs/2026-04-22-claude-code-hook-bridging-design.md
git commit -m "Log hook bridging implementation completion"
```

---

## Non-Goals (reiteration)

- No PostToolUse / SessionStart / SessionEnd / SubagentStop / PreCompact
- No multi-session concurrent approval queue (single pending at a time; later ones queue)
- No Cursor native integration (protocol is documented, manual integration possible)
- No iOS code changes
- No configurable timeout (fixed 30s, falls back to `ask`)
