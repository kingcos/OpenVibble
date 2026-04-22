// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
