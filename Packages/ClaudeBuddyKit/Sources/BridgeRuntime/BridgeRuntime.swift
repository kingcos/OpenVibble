import Foundation
import BuddyProtocol
import BuddyStorage

public struct PromptRequest: Equatable, Sendable {
    public let id: String
    public let tool: String
    public let hint: String

    public init(id: String, tool: String, hint: String) {
        self.id = id
        self.tool = tool
        self.hint = hint
    }
}

public struct BridgeSnapshot: Equatable, Sendable {
    public var total: Int
    public var running: Int
    public var waiting: Int
    public var msg: String
    public var entries: [String]
    public var tokens: Int
    public var tokensToday: Int
    public var ownerName: String
    public var deviceName: String
    public var lastTurnRole: String
    public var lastTurnPreview: String

    public static let empty = BridgeSnapshot(
        total: 0,
        running: 0,
        waiting: 0,
        msg: "未连接 Claude Desktop",
        entries: [],
        tokens: 0,
        tokensToday: 0,
        ownerName: "",
        deviceName: "Claude-iOS",
        lastTurnRole: "",
        lastTurnPreview: ""
    )

    public init(
        total: Int,
        running: Int,
        waiting: Int,
        msg: String,
        entries: [String],
        tokens: Int,
        tokensToday: Int,
        ownerName: String,
        deviceName: String,
        lastTurnRole: String,
        lastTurnPreview: String
    ) {
        self.total = total
        self.running = running
        self.waiting = waiting
        self.msg = msg
        self.entries = entries
        self.tokens = tokens
        self.tokensToday = tokensToday
        self.ownerName = ownerName
        self.deviceName = deviceName
        self.lastTurnRole = lastTurnRole
        self.lastTurnPreview = lastTurnPreview
    }
}

public final class BridgeRuntime {
    private var snapshotStorage: BridgeSnapshot
    private var promptStorage: PromptRequest?
    private let transferStore: CharacterTransferStore

    public var onCharacterInstalled: ((String) -> Void)?
    public var charactersRootURL: URL { transferStore.charactersRootURL }

    public init(initialSnapshot: BridgeSnapshot = .empty, transferStore: CharacterTransferStore = CharacterTransferStore()) {
        self.snapshotStorage = initialSnapshot
        self.transferStore = transferStore
    }

    public func ingestLine(_ line: String) -> [String] {
        do {
            let message = try NDJSONCodec.decodeInboundLine(line)
            switch message {
            case .heartbeat(let heartbeat):
                snapshotStorage.total = heartbeat.total
                snapshotStorage.running = heartbeat.running
                snapshotStorage.waiting = heartbeat.waiting
                snapshotStorage.msg = heartbeat.msg
                snapshotStorage.entries = heartbeat.entries
                snapshotStorage.tokens = heartbeat.tokens ?? snapshotStorage.tokens
                snapshotStorage.tokensToday = heartbeat.tokensToday ?? snapshotStorage.tokensToday
                if let prompt = heartbeat.prompt {
                    promptStorage = PromptRequest(id: prompt.id, tool: prompt.tool ?? "", hint: prompt.hint ?? "")
                } else {
                    promptStorage = nil
                }
                return []

            case .turn(let event):
                snapshotStorage.lastTurnRole = event.role
                snapshotStorage.lastTurnPreview = event.content.first.map { describeJSON($0) } ?? ""
                return []

            case .timeSync:
                return []

            case .command(let command):
                return handleCommand(command)
            }
        } catch {
            return []
        }
    }

    public func handleCommand(_ command: BridgeCommand) -> [String] {
        switch command {
        case .status:
            return [encodeAck(makeStatusAck())]

        case .name(let name):
            snapshotStorage.deviceName = name.isEmpty ? snapshotStorage.deviceName : name
            return [encodeAck(BridgeAck(ack: "name", ok: !name.isEmpty, n: 0, error: name.isEmpty ? "name required" : nil))]

        case .owner(let name):
            snapshotStorage.ownerName = name
            return [encodeAck(BridgeAck(ack: "owner", ok: !name.isEmpty, n: 0, error: name.isEmpty ? "owner required" : nil))]

        case .unpair:
            promptStorage = nil
            transferStore.reset()
            let ack = BridgeAck(ack: "unpair", ok: true, n: 0, error: "ios_bond_reset_requires_system_forget")
            return [encodeAck(ack)]

        case .charBegin(let name, let total):
            return [encodeAck(transferStore.beginCharacter(name: name, totalBytes: total))]

        case .file(let path, let size):
            return [encodeAck(transferStore.openFile(path: path, size: size))]

        case .chunk(let base64):
            return [encodeAck(transferStore.appendChunk(base64: base64))]

        case .fileEnd:
            return [encodeAck(transferStore.closeFile())]

        case .charEnd:
            let installedName = transferStore.progress.characterName
            let ack = transferStore.finishCharacter()
            if ack.ok, !installedName.isEmpty {
                onCharacterInstalled?(installedName)
            }
            return [encodeAck(ack)]

        case .permission:
            return []

        case .unknown(let command):
            return [encodeAck(BridgeAck(ack: command, ok: false, n: 0, error: "unsupported command"))]
        }
    }

    public func currentSnapshot() -> BridgeSnapshot {
        snapshotStorage
    }

    public func pendingPrompt() -> PromptRequest? {
        promptStorage
    }

    public func transferProgress() -> TransferProgress {
        transferStore.progress
    }

    public func respondPermission(_ decision: PermissionDecision) -> String? {
        guard let promptStorage else { return nil }
        let command = PermissionCommand(id: promptStorage.id, decision: decision)
        return try? NDJSONCodec.encodeLine(command)
    }

    private func makeStatusAck() -> BridgeAck {
        let transfer = transferStore.progress

        let payload: [String: JSONValue] = [
            "name": .string(snapshotStorage.deviceName),
            "owner": .string(snapshotStorage.ownerName),
            "sec": .bool(true),
            "bat": .object([
                "pct": .number(100),
                "mV": .number(4000),
                "mA": .number(0),
                "usb": .bool(true)
            ]),
            "sys": .object([
                "up": .number(ProcessInfo.processInfo.systemUptime),
                "heap": .number(0)
            ]),
            "stats": .object([
                "appr": .number(Double(snapshotStorage.running)),
                "deny": .number(Double(snapshotStorage.waiting)),
                "vel": .number(Double(snapshotStorage.total)),
                "nap": .number(0),
                "lvl": .number(Double(snapshotStorage.tokens / 50_000))
            ]),
            "xfer": .object([
                "active": .bool(transfer.isActive),
                "total": .number(Double(transfer.totalBytes)),
                "written": .number(Double(transfer.writtenBytes))
            ])
        ]

        return BridgeAck(ack: "status", ok: true, n: 0, data: .object(payload))
    }

    private func encodeAck(_ ack: BridgeAck) -> String {
        (try? NDJSONCodec.encodeLine(ack)) ?? "{\"ack\":\"invalid\",\"ok\":false}\n"
    }

    private func describeJSON(_ value: JSONValue) -> String {
        switch value {
        case .string(let text):
            return text
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .object:
            return "{...}"
        case .array:
            return "[...]"
        case .null:
            return "null"
        }
    }
}
