// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct PersonaStats: Codable, Sendable, Equatable {
    public static let tokensPerLevel: UInt32 = 50_000
    public static let velocityRingSize: Int = 8

    public var approvals: UInt16
    public var denials: UInt16
    public var velocity: [UInt16]
    public var velIdx: UInt8
    public var velCount: UInt8
    public var level: UInt8
    public var tokens: UInt32
    public var napSeconds: UInt32

    public init(
        approvals: UInt16 = 0,
        denials: UInt16 = 0,
        velocity: [UInt16] = Array(repeating: 0, count: 8),
        velIdx: UInt8 = 0,
        velCount: UInt8 = 0,
        level: UInt8 = 0,
        tokens: UInt32 = 0,
        napSeconds: UInt32 = 0
    ) {
        self.approvals = approvals
        self.denials = denials
        self.velocity = velocity
        self.velIdx = velIdx
        self.velCount = velCount
        self.level = level
        self.tokens = tokens
        self.napSeconds = napSeconds
    }

    public var derivedLevel: UInt8 {
        UInt8(min(UInt32(UInt8.max), tokens / Self.tokensPerLevel))
    }

    public var fedProgress: UInt8 {
        // 0..9: tokens within current level / (level_size/10)
        let partial = tokens % Self.tokensPerLevel
        let perPip = Self.tokensPerLevel / 10
        return UInt8(min(9, partial / perPip))
    }

    public var medianVelocitySeconds: UInt16 {
        guard velCount > 0 else { return 0 }
        let slice = velocity.prefix(Int(velCount))
        let sorted = slice.sorted()
        return sorted[Int(velCount) / 2]
    }

    /// 0..4 tier. Faster median response = higher; heavy deny rate pulls it down.
    public var moodTier: UInt8 {
        var tier: Int
        let vel = medianVelocitySeconds
        if vel == 0 { tier = 2 }
        else if vel < 15 { tier = 4 }
        else if vel < 30 { tier = 3 }
        else if vel < 60 { tier = 2 }
        else if vel < 120 { tier = 1 }
        else { tier = 0 }
        let a = Int(approvals), d = Int(denials)
        if a + d >= 3 {
            if d > a { tier -= 2 }
            else if d * 2 > a { tier -= 1 }
        }
        return UInt8(max(0, min(4, tier)))
    }
}
