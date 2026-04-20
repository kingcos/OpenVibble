import XCTest
@testable import BuddyStats

final class PersonaStatsTests: XCTestCase {
    func test_derivedLevel_matchesTokenBuckets() {
        XCTAssertEqual(PersonaStats(tokens: 0).derivedLevel, 0)
        XCTAssertEqual(PersonaStats(tokens: 49_999).derivedLevel, 0)
        XCTAssertEqual(PersonaStats(tokens: 50_000).derivedLevel, 1)
        XCTAssertEqual(PersonaStats(tokens: 125_000).derivedLevel, 2)
    }

    func test_fedProgress_acrossLevelBoundary() {
        XCTAssertEqual(PersonaStats(tokens: 0).fedProgress, 0)
        XCTAssertEqual(PersonaStats(tokens: 25_000).fedProgress, 5)
        XCTAssertEqual(PersonaStats(tokens: 49_999).fedProgress, 9)
        XCTAssertEqual(PersonaStats(tokens: 50_000).fedProgress, 0)
    }

    func test_medianVelocity_empty_returnsZero() {
        let s = PersonaStats()
        XCTAssertEqual(s.medianVelocitySeconds, 0)
    }

    func test_medianVelocity_usesOnlyFilledSlots() {
        var s = PersonaStats()
        s.velocity[0] = 5
        s.velocity[1] = 15
        s.velocity[2] = 25
        s.velCount = 3
        XCTAssertEqual(s.medianVelocitySeconds, 15)
    }

    func test_moodTier_fastResponder_highMood() {
        var s = PersonaStats()
        s.velocity[0] = 10
        s.velCount = 1
        s.approvals = 5
        XCTAssertEqual(s.moodTier, 4)
    }

    func test_moodTier_slowResponder_lowMood() {
        var s = PersonaStats()
        s.velocity[0] = 200
        s.velCount = 1
        XCTAssertEqual(s.moodTier, 0)
    }

    func test_moodTier_heavyDenyRate_pullsDown() {
        var s = PersonaStats()
        s.velocity[0] = 10  // base tier 4
        s.velCount = 1
        s.approvals = 1
        s.denials = 3       // d > a
        XCTAssertEqual(s.moodTier, 2)  // 4 - 2
    }
}
