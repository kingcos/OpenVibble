import Foundation

public struct NDJSONLineFramer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func ingest(_ chunk: Data) throws -> [String] {
        buffer.append(chunk)
        var lines: [String] = []

        while let index = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[..<index]
            buffer.removeSubrange(...index)
            if lineData.isEmpty { continue }
            if let line = String(data: lineData, encoding: .utf8) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append(trimmed)
                }
            }
        }

        return lines
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}

public enum NDJSONCodec {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    public static let decoder = JSONDecoder()

    public static func encodeLine<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let body = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return body + "\n"
    }

    public static func decodeInboundLine(_ line: String) throws -> BridgeInboundMessage {
        let data = Data(line.utf8)

        if let time = try? decoder.decode(TimeSync.self, from: data) {
            return .timeSync(time)
        }

        if let turn = try? decoder.decode(TurnEvent.self, from: data), turn.evt == "turn" {
            return .turn(turn)
        }

        if let heartbeat = try? decoder.decode(HeartbeatSnapshot.self, from: data) {
            return .heartbeat(heartbeat)
        }

        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let cmd = object["cmd"] as? String
        else {
            throw BridgeProtocolError.invalidEnvelope
        }

        switch cmd {
        case "status":
            return .command(.status)
        case "name":
            return .command(.name(object["name"] as? String ?? ""))
        case "owner":
            return .command(.owner(object["name"] as? String ?? ""))
        case "unpair":
            return .command(.unpair)
        case "char_begin":
            return .command(.charBegin(name: object["name"] as? String ?? "", total: object["total"] as? Int ?? 0))
        case "file":
            return .command(.file(path: object["path"] as? String ?? "", size: object["size"] as? Int ?? 0))
        case "chunk":
            return .command(.chunk(base64: object["d"] as? String ?? ""))
        case "file_end":
            return .command(.fileEnd)
        case "char_end":
            return .command(.charEnd)
        case "permission":
            let decisionRaw = object["decision"] as? String ?? "deny"
            let decision = PermissionDecision(rawValue: decisionRaw) ?? .deny
            return .command(.permission(id: object["id"] as? String ?? "", decision: decision))
        default:
            return .command(.unknown(cmd))
        }
    }
}
