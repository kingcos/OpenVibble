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
