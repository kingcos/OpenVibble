import Foundation
import BuddyProtocol

/// Messages the central receives from the iOS peripheral over the TX characteristic.
/// On this side we expect heartbeats, turn events, and acks — never commands
/// (those flow the other way, central → peripheral, over RX).
public enum CentralInboundMessage: Equatable, Sendable {
    case heartbeat(HeartbeatSnapshot)
    case turn(TurnEvent)
    case timeSync(TimeSync)
    case ack(BridgeAck)
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
        if let heartbeat = try? decoder.decode(HeartbeatSnapshot.self, from: data) {
            return .heartbeat(heartbeat)
        }
        if let time = try? decoder.decode(TimeSync.self, from: data) {
            return .timeSync(time)
        }
        return .unknown(line)
    }
}
