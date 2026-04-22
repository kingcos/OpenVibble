import Foundation

public enum HookEvent: String, Codable, CaseIterable, Sendable {
    case preToolUse = "PreToolUse"
    case permissionRequest = "PermissionRequest"
    case userPromptSubmit = "UserPromptSubmit"
    case stop = "Stop"
    case stopFailure = "StopFailure"
    case notification = "Notification"
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"

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

    public var pendingPersonaIntent: PersonaIntent {
        switch self {
        case .permissionRequest: return .attention(overlay: .heart)
        default: return .idle
        }
    }

    public var transientPersonaIntent: PersonaIntent {
        switch self {
        case .preToolUse: return .busy(duration: 0.5)
        case .permissionRequest: return .attention(overlay: .heart)
        case .userPromptSubmit: return .busy(duration: 1.0)
        case .stop: return .celebrate(duration: 3.0)
        case .stopFailure: return .dizzy(duration: 2.0)
        case .notification: return .attention(duration: 2.0)
        case .sessionStart: return .busy(duration: 1.0)
        case .sessionEnd: return .idle
        case .subagentStart: return .busy(duration: 1.5)
        case .subagentStop: return .idle
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
