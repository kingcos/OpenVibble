import Foundation

public enum CentralConnectionState: Equatable, Sendable {
    case unknown
    case unsupported
    case unauthorized
    case poweredOff
    case idle
    case scanning
    case connecting
    case connected
    case disconnecting
    case error(String)
}

public struct DiscoveredPeripheral: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let lastSeen: Date

    public init(id: UUID, name: String, rssi: Int, lastSeen: Date) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.lastSeen = lastSeen
    }
}
