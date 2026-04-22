// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
