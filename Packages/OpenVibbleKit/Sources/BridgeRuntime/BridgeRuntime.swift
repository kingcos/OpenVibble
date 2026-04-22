// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import BuddyProtocol
import BuddyPersona
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

public struct BatterySample: Equatable, Sendable {
    public var percent: Int
    public var millivolts: Int
    public var milliamps: Int
    public var usb: Bool

    public init(percent: Int, millivolts: Int = 0, milliamps: Int = 0, usb: Bool = false) {
        self.percent = percent
        self.millivolts = millivolts
        self.milliamps = milliamps
        self.usb = usb
    }
}

public struct StatsSample: Equatable, Sendable {
    public var approvals: Int
    public var denials: Int
    public var velocityMedianSeconds: Int
    public var napSeconds: Int
    public var level: Int

    public init(approvals: Int, denials: Int, velocityMedianSeconds: Int, napSeconds: Int, level: Int) {
        self.approvals = approvals
        self.denials = denials
        self.velocityMedianSeconds = velocityMedianSeconds
        self.napSeconds = napSeconds
        self.level = level
    }
}

public struct StatusSample: Equatable, Sendable {
    public var battery: BatterySample
    public var stats: StatsSample

    public init(battery: BatterySample, stats: StatsSample) {
        self.battery = battery
        self.stats = stats
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
        msg: "",
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
    /// Most recent prompt id we already answered via `respondPermission`. The
    /// desktop needs a round-trip before its next heartbeat reflects the
    /// response, and during that window `ingestLine` would otherwise re-seat
    /// the same prompt and make the UI bounce (island button reappears, etc.).
    /// Cleared once the desktop confirms with a heartbeat whose `prompt` is
    /// absent or carries a different id.
    private var lastAnsweredPromptId: String?
    private let transferStore: CharacterTransferStore
    private var lastStatusSample: StatusSample?
    private let startDate = Date()

    public var onCharacterInstalled: ((String) -> Void)?
    public var onSpeciesChanged: ((Int) -> Void)?
    public var onTaskCompleted: (() -> Void)?
    public var charactersRootURL: URL { transferStore.charactersRootURL }

    public init(initialSnapshot: BridgeSnapshot = .empty, transferStore: CharacterTransferStore = CharacterTransferStore()) {
        self.snapshotStorage = initialSnapshot
        self.transferStore = transferStore
    }

    public func updateStatusSample(_ sample: StatusSample) {
        lastStatusSample = sample
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
                    if prompt.id == lastAnsweredPromptId {
                        // Desktop hasn't yet acknowledged our response — treat
                        // this stale prompt as cleared so the UI stays quiet
                        // instead of bouncing between "answered" and "pending".
                        promptStorage = nil
                    } else {
                        promptStorage = PromptRequest(id: prompt.id, tool: prompt.tool ?? "", hint: prompt.hint ?? "")
                        // A different prompt id means the desktop has moved
                        // on; the previous answer is now irrelevant.
                        lastAnsweredPromptId = nil
                    }
                } else {
                    promptStorage = nil
                    lastAnsweredPromptId = nil
                }
                if heartbeat.completed == true {
                    onTaskCompleted?()
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
            lastAnsweredPromptId = nil
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

        case .species(let idx):
            if idx == PersonaSpeciesCatalog.gifSentinel {
                // 0xFF = restore GIF; keep current PersonaSelection if it is already
                // builtin/installed, otherwise fall back to default ascii cat.
                let current = PersonaSelection.load()
                switch current {
                case .builtin, .installed:
                    break
                default:
                    PersonaSelection.save(.asciiCat)
                }
                onSpeciesChanged?(idx)
                return [encodeAck(BridgeAck(ack: "species", ok: true, n: 0))]
            }
            guard PersonaSpeciesCatalog.isValid(idx: idx) else {
                return [encodeAck(BridgeAck(ack: "species", ok: false, n: 0, error: "invalid idx"))]
            }
            PersonaSelection.save(.asciiSpecies(idx: idx))
            onSpeciesChanged?(idx)
            return [encodeAck(BridgeAck(ack: "species", ok: true, n: 0))]

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
        guard let line = try? NDJSONCodec.encodeLine(command) else { return nil }
        // Optimistically drop the pending prompt so the UI (Home, Live
        // Activity, notification drawer) collapses to "no prompt" without
        // waiting for the next heartbeat round-trip.
        lastAnsweredPromptId = promptStorage.id
        self.promptStorage = nil
        return line
    }

    private func makeStatusAck() -> BridgeAck {
        let transfer = transferStore.progress
        let battery = lastStatusSample?.battery ?? BatterySample(percent: 100, millivolts: 4000, milliamps: 0, usb: true)
        let stats: StatsSample = lastStatusSample?.stats ?? StatsSample(
            approvals: snapshotStorage.running,
            denials: snapshotStorage.waiting,
            velocityMedianSeconds: snapshotStorage.total,
            napSeconds: 0,
            level: Int(snapshotStorage.tokens / 50_000)
        )

        // Session-scoped uptime (seconds since this BridgeRuntime started) —
        // matches h5-demo's `performance.now()/1000` and firmware's
        // `millis()/1000` semantics. Using ProcessInfo.systemUptime would
        // return device boot uptime, which isn't what the Claude desktop
        // expects for per-session stats.
        let up = Int(Date().timeIntervalSince(startDate))
        let (fsFree, fsTotal) = filesystemCapacity(at: transferStore.charactersRootURL)

        // iOS cannot enforce LE Secure Connections bonding via CoreBluetooth
        // Peripheral — report sec=false so the desktop knows transcripts are
        // unencrypted in this direction.
        let payload: [String: JSONValue] = [
            "name": .string(snapshotStorage.deviceName),
            "owner": .string(snapshotStorage.ownerName),
            "sec": .bool(false),
            "bat": .object([
                "pct": .number(Double(battery.percent)),
                "mV": .number(Double(battery.millivolts)),
                "mA": .number(Double(battery.milliamps)),
                "usb": .bool(battery.usb)
            ]),
            "sys": .object([
                "up": .number(Double(up)),
                "heap": .number(0),
                "fsFree": .number(Double(fsFree)),
                "fsTotal": .number(Double(fsTotal))
            ]),
            "stats": .object([
                "appr": .number(Double(stats.approvals)),
                "deny": .number(Double(stats.denials)),
                "vel": .number(Double(stats.velocityMedianSeconds)),
                "nap": .number(Double(stats.napSeconds)),
                "lvl": .number(Double(stats.level))
            ]),
            // iOS-only extension. Firmware/h5 status payload doesn't include
            // this, so Claude Desktop treats it as advisory.
            "xfer": .object([
                "active": .bool(transfer.isActive),
                "total": .number(Double(transfer.totalBytes)),
                "written": .number(Double(transfer.writtenBytes))
            ])
        ]

        return BridgeAck(ack: "status", ok: true, n: 0, data: .object(payload))
    }

    private func filesystemCapacity(at url: URL) -> (free: Int64, total: Int64) {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return (0, 0)
        }
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values.volumeTotalCapacity ?? 0)
        return (free, total)
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
