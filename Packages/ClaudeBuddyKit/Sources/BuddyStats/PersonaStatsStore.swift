import Foundation
import Combine

@MainActor
public final class PersonaStatsStore: ObservableObject {
    @Published public private(set) var stats: PersonaStats

    // First-sight latch for bridge token sync.
    // On app restart, tokens counter starts back at 0 on our side — but the bridge
    // still reports its cumulative total. Without the latch we'd re-credit the
    // entire session the moment the first heartbeat arrives.
    private var lastBridgeTokens: UInt32 = 0
    private var tokensSynced: Bool = false

    private var lastWakeDate: Date
    private var energyAtWake: UInt8 = 3
    private let defaults: UserDefaults

    public static let storageKey = "buddy.stats.v1"
    public static let lastNapEndKey = "buddy.stats.lastNapEnd"

    public init(defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults

        var initialStats: PersonaStats
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(PersonaStats.self, from: data) {
            initialStats = decoded
        } else {
            initialStats = PersonaStats()
        }
        // Backfill: derived tokens from persisted level if out of sync
        if initialStats.tokens == 0, initialStats.level > 0 {
            initialStats.tokens = UInt32(initialStats.level) * PersonaStats.tokensPerLevel
        }
        self.stats = initialStats

        if let napEndRaw = defaults.object(forKey: Self.lastNapEndKey) as? Date {
            self.lastWakeDate = napEndRaw
        } else {
            self.lastWakeDate = now
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    // MARK: - Events

    public func onApproval(secondsToRespond: TimeInterval) {
        var s = stats
        s.approvals &+= 1
        let clamped = UInt16(max(0, min(65_535, Int(secondsToRespond.rounded()))))
        s.velocity[Int(s.velIdx)] = clamped
        s.velIdx = (s.velIdx &+ 1) % UInt8(PersonaStats.velocityRingSize)
        if s.velCount < UInt8(PersonaStats.velocityRingSize) { s.velCount &+= 1 }
        stats = s
        save()
    }

    public func onDenial() {
        var s = stats
        s.denials &+= 1
        stats = s
        save()
    }

    /// Returns true if this delta caused a level-up.
    @discardableResult
    public func onBridgeTokens(_ bridgeTotal: Int) -> Bool {
        let total = UInt32(max(0, bridgeTotal))
        if !tokensSynced {
            lastBridgeTokens = total
            tokensSynced = true
            return false
        }
        if total < lastBridgeTokens {
            // Bridge restarted. Resync without crediting.
            lastBridgeTokens = total
            return false
        }
        let delta = total - lastBridgeTokens
        lastBridgeTokens = total
        if delta == 0 { return false }

        var s = stats
        let lvlBefore = UInt8(min(UInt32(UInt8.max), s.tokens / PersonaStats.tokensPerLevel))
        s.tokens = s.tokens &+ delta
        let lvlAfter = UInt8(min(UInt32(UInt8.max), s.tokens / PersonaStats.tokensPerLevel))
        if lvlAfter > lvlBefore {
            s.level = lvlAfter
            stats = s
            save()
            return true
        }
        stats = s
        // Don't persist every heartbeat — only persist on level milestones.
        // Non-milestone token accrual is RAM-only here too.
        return false
    }

    public func onNapEnd(seconds: TimeInterval, now: Date = .now) {
        var s = stats
        s.napSeconds = s.napSeconds &+ UInt32(max(0, seconds.rounded()))
        stats = s
        lastWakeDate = now
        energyAtWake = 5
        defaults.set(now, forKey: Self.lastNapEndKey)
        save()
    }

    public func energyTier(now: Date = .now) -> UInt8 {
        let hoursSince = UInt32(max(0, now.timeIntervalSince(lastWakeDate) / 3600))
        let e = Int(energyAtWake) - Int(hoursSince / 2)
        return UInt8(max(0, min(5, e)))
    }

    public func reset() {
        stats = PersonaStats()
        tokensSynced = false
        lastBridgeTokens = 0
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.lastNapEndKey)
    }
}
