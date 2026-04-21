import XCTest
@testable import BuddyStats

@MainActor
final class PersonaStatsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "buddy.tests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_onBridgeTokens_firstSight_latchesWithoutCrediting() {
        let store = PersonaStatsStore(defaults: defaults)
        _ = store.onBridgeTokens(10_000)
        XCTAssertEqual(store.stats.tokens, 0, "first heartbeat must latch, not credit")
    }

    func test_onBridgeTokens_secondDelta_credits() {
        let store = PersonaStatsStore(defaults: defaults)
        _ = store.onBridgeTokens(10_000)
        _ = store.onBridgeTokens(12_000)
        XCTAssertEqual(store.stats.tokens, 2_000)
    }

    func test_onBridgeTokens_bridgeRestart_resyncsWithoutCrediting() {
        let store = PersonaStatsStore(defaults: defaults)
        _ = store.onBridgeTokens(10_000)
        _ = store.onBridgeTokens(20_000)      // credit 10k
        XCTAssertEqual(store.stats.tokens, 10_000)
        _ = store.onBridgeTokens(5_000)       // regression → resync
        XCTAssertEqual(store.stats.tokens, 10_000)
        _ = store.onBridgeTokens(6_000)       // credit 1k
        XCTAssertEqual(store.stats.tokens, 11_000)
    }

    func test_onBridgeTokens_crossesLevelBoundary_returnsTrue() {
        let store = PersonaStatsStore(defaults: defaults)
        _ = store.onBridgeTokens(0)
        let leveled = store.onBridgeTokens(60_000)  // 50k tokensPerLevel
        XCTAssertTrue(leveled)
        XCTAssertEqual(store.stats.level, 1)
    }

    func test_onBridgeTokens_belowLevelBoundary_returnsFalse() {
        let store = PersonaStatsStore(defaults: defaults)
        _ = store.onBridgeTokens(0)
        let leveled = store.onBridgeTokens(1_000)
        XCTAssertFalse(leveled)
        XCTAssertEqual(store.stats.level, 0)
    }

    func test_onApproval_updatesVelocityRing() {
        let store = PersonaStatsStore(defaults: defaults)
        store.onApproval(secondsToRespond: 10)
        store.onApproval(secondsToRespond: 20)
        XCTAssertEqual(store.stats.approvals, 2)
        XCTAssertEqual(store.stats.velCount, 2)
        XCTAssertEqual(store.stats.velocity[0], 10)
        XCTAssertEqual(store.stats.velocity[1], 20)
    }

    func test_onDenial_increments() {
        let store = PersonaStatsStore(defaults: defaults)
        store.onDenial()
        XCTAssertEqual(store.stats.denials, 1)
    }

    func test_reset_clearsStatsAndLatch() {
        let store = PersonaStatsStore(defaults: defaults)
        _ = store.onBridgeTokens(10_000)
        _ = store.onBridgeTokens(12_000)
        store.onApproval(secondsToRespond: 5)
        XCTAssertGreaterThan(store.stats.tokens, 0)

        store.reset()
        XCTAssertEqual(store.stats, PersonaStats())

        // Latch is also cleared: next bridge total must latch again.
        _ = store.onBridgeTokens(99_000)
        XCTAssertEqual(store.stats.tokens, 0)
    }

    func test_energyTier_decaysOverTime() {
        let store = PersonaStatsStore(defaults: defaults)
        let baseline = Date()
        store.onNapEnd(seconds: 60, now: baseline)
        XCTAssertEqual(store.energyTier(now: baseline), 5)
        // 4 hours later → energy drops by 2 (every 2h)
        let later = baseline.addingTimeInterval(4 * 3600)
        XCTAssertEqual(store.energyTier(now: later), 3)
    }

    func test_persistence_roundTrip() {
        do {
            let store = PersonaStatsStore(defaults: defaults)
            store.onApproval(secondsToRespond: 12)
            _ = store.onBridgeTokens(0)
            _ = store.onBridgeTokens(55_000)   // level up → persists
            XCTAssertEqual(store.stats.level, 1)
        }
        let reloaded = PersonaStatsStore(defaults: defaults)
        XCTAssertEqual(reloaded.stats.approvals, 1)
        XCTAssertEqual(reloaded.stats.level, 1)
    }
}
