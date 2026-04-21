import Foundation

public struct BridgeAck: Codable, Equatable, Sendable {
    public let ack: String
    public let ok: Bool
    public let n: Int?
    public let error: String?
    public let data: JSONValue?

    public init(ack: String, ok: Bool, n: Int? = nil, error: String? = nil, data: JSONValue? = nil) {
        self.ack = ack
        self.ok = ok
        self.n = n
        self.error = error
        self.data = data
    }
}

public struct TimeSync: Codable, Equatable, Sendable {
    public let epochSeconds: Int64
    public let timezoneOffsetSeconds: Int

    public init(epochSeconds: Int64, timezoneOffsetSeconds: Int) {
        self.epochSeconds = epochSeconds
        self.timezoneOffsetSeconds = timezoneOffsetSeconds
    }

    enum CodingKeys: String, CodingKey {
        case time
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var values = try container.nestedUnkeyedContainer(forKey: .time)
        let epoch = try values.decode(Int64.self)
        let timezone = try values.decode(Int.self)
        self.init(epochSeconds: epoch, timezoneOffsetSeconds: timezone)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var values = container.nestedUnkeyedContainer(forKey: .time)
        try values.encode(epochSeconds)
        try values.encode(timezoneOffsetSeconds)
    }
}

public struct HeartbeatPrompt: Codable, Equatable, Sendable {
    public let id: String
    public let tool: String?
    public let hint: String?

    public init(id: String, tool: String?, hint: String?) {
        self.id = id
        self.tool = tool
        self.hint = hint
    }
}

public struct HeartbeatSnapshot: Codable, Equatable, Sendable {
    public let total: Int
    public let running: Int
    public let waiting: Int
    public let msg: String
    public let entries: [String]
    public let tokens: Int?
    public let tokensToday: Int?
    public let prompt: HeartbeatPrompt?
    public let completed: Bool?

    enum CodingKeys: String, CodingKey {
        case total, running, waiting, msg, entries, tokens, prompt, completed
        case tokensToday = "tokens_today"
    }

    public init(
        total: Int,
        running: Int,
        waiting: Int,
        msg: String,
        entries: [String],
        tokens: Int?,
        tokensToday: Int?,
        prompt: HeartbeatPrompt?,
        completed: Bool? = nil
    ) {
        self.total = total
        self.running = running
        self.waiting = waiting
        self.msg = msg
        self.entries = entries
        self.tokens = tokens
        self.tokensToday = tokensToday
        self.prompt = prompt
        self.completed = completed
    }
}

public struct TurnEvent: Codable, Equatable, Sendable {
    public let evt: String
    public let role: String
    public let content: [JSONValue]

    public init(evt: String, role: String, content: [JSONValue]) {
        self.evt = evt
        self.role = role
        self.content = content
    }
}

public enum PermissionDecision: String, Codable, Equatable, Sendable {
    case once
    case deny
}

public struct PermissionCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let id: String
    public let decision: PermissionDecision

    public init(id: String, decision: PermissionDecision) {
        self.cmd = "permission"
        self.id = id
        self.decision = decision
    }
}

public struct NameCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let name: String

    public init(name: String) {
        self.cmd = "name"
        self.name = name
    }
}

public struct OwnerCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let name: String

    public init(name: String) {
        self.cmd = "owner"
        self.name = name
    }
}

public struct StatusCommand: Codable, Equatable, Sendable {
    public let cmd: String

    public init() {
        self.cmd = "status"
    }
}

public struct UnpairCommand: Codable, Equatable, Sendable {
    public let cmd: String

    public init() {
        self.cmd = "unpair"
    }
}

public struct CharBeginCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let name: String
    public let total: Int

    public init(name: String, total: Int) {
        self.cmd = "char_begin"
        self.name = name
        self.total = total
    }
}

public struct FileCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let path: String
    public let size: Int

    public init(path: String, size: Int) {
        self.cmd = "file"
        self.path = path
        self.size = size
    }
}

public struct ChunkCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let d: String

    public init(base64: String) {
        self.cmd = "chunk"
        self.d = base64
    }
}

public struct FileEndCommand: Codable, Equatable, Sendable {
    public let cmd: String

    public init() {
        self.cmd = "file_end"
    }
}

public struct CharEndCommand: Codable, Equatable, Sendable {
    public let cmd: String

    public init() {
        self.cmd = "char_end"
    }
}

public struct SpeciesCommand: Codable, Equatable, Sendable {
    public let cmd: String
    public let idx: Int

    public init(idx: Int) {
        self.cmd = "species"
        self.idx = idx
    }
}

public enum BridgeCommand: Equatable, Sendable {
    case status
    case name(String)
    case owner(String)
    case unpair
    case charBegin(name: String, total: Int)
    case file(path: String, size: Int)
    case chunk(base64: String)
    case fileEnd
    case charEnd
    case permission(id: String, decision: PermissionDecision)
    case species(idx: Int)
    case unknown(String)
}

public enum BridgeInboundMessage: Equatable, Sendable {
    case heartbeat(HeartbeatSnapshot)
    case turn(TurnEvent)
    case timeSync(TimeSync)
    case command(BridgeCommand)
}

public enum BridgeProtocolError: Error, Equatable {
    case invalidEnvelope
}
