import XCTest
@testable import BuddyPersona

final class PersonaStateTests: XCTestCase {
    func test_derive_disconnected_returnsIdle() {
        let s = derivePersonaState(.init(connected: false, sessionsRunning: 5, sessionsWaiting: 5, recentlyCompleted: false))
        XCTAssertEqual(s, .idle)
    }

    func test_derive_recentlyCompleted_returnsCelebrate_overridesEverything() {
        let s = derivePersonaState(.init(connected: true, sessionsRunning: 3, sessionsWaiting: 2, recentlyCompleted: true))
        XCTAssertEqual(s, .celebrate)
    }

    func test_derive_waiting_returnsAttention() {
        let s = derivePersonaState(.init(connected: true, sessionsRunning: 0, sessionsWaiting: 1, recentlyCompleted: false))
        XCTAssertEqual(s, .attention)
    }

    func test_derive_running_returnsBusy() {
        let s = derivePersonaState(.init(connected: true, sessionsRunning: 1, sessionsWaiting: 0, recentlyCompleted: false))
        XCTAssertEqual(s, .busy)
    }

    func test_derive_idle_whenConnectedButIdle() {
        let s = derivePersonaState(.init(connected: true, sessionsRunning: 0, sessionsWaiting: 0, recentlyCompleted: false))
        XCTAssertEqual(s, .idle)
    }

    func test_overlay_dizzyBeforeExpiry_wins() {
        let now = Date()
        let result = resolvePersonaState(base: .busy, overlay: .dizzy(until: now.addingTimeInterval(1)), now: now)
        XCTAssertEqual(result, .dizzy)
    }

    func test_overlay_dizzyAfterExpiry_fallsBackToBase() {
        let now = Date()
        let result = resolvePersonaState(base: .busy, overlay: .dizzy(until: now.addingTimeInterval(-1)), now: now)
        XCTAssertEqual(result, .busy)
    }

    func test_overlay_heartBeforeExpiry_wins() {
        let now = Date()
        let result = resolvePersonaState(base: .idle, overlay: .heart(until: now.addingTimeInterval(1)), now: now)
        XCTAssertEqual(result, .heart)
    }

    func test_overlay_sleepRequires3Seconds() {
        let now = Date()
        let notYet = resolvePersonaState(base: .idle, overlay: .sleep(since: now.addingTimeInterval(-1)), now: now)
        XCTAssertEqual(notYet, .idle)
        let elapsed = resolvePersonaState(base: .idle, overlay: .sleep(since: now.addingTimeInterval(-4)), now: now)
        XCTAssertEqual(elapsed, .sleep)
    }

    func test_slug_roundTrip() {
        for state in PersonaState.allCases {
            XCTAssertFalse(state.slug.isEmpty)
        }
    }
}
