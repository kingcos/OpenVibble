import Foundation
import Testing
@testable import HookBridge

@Suite("HookActivity")
struct HookActivityTests {
    @Test func appendIsMostRecentFirst() {
        var log = HookActivityLog(capacity: 50)
        log.append(HookActivityEntry(event: .stop, projectName: "a"))
        log.append(HookActivityEntry(event: .preToolUse, projectName: "b"))
        #expect(log.recent.first?.event == .preToolUse)
        #expect(log.recent.last?.event == .stop)
    }

    @Test func capacityIsEnforced() {
        var log = HookActivityLog(capacity: 3)
        for i in 0..<10 {
            log.append(HookActivityEntry(event: .stop, projectName: "p\(i)"))
        }
        #expect(log.recent.count == 3)
        #expect(log.recent.first?.projectName == "p9")
        #expect(log.recent.last?.projectName == "p7")
    }

    @Test func perEventStatsTracksCountAndLastFired() {
        var log = HookActivityLog(capacity: 10)
        let e1 = HookActivityEntry(event: .preToolUse, projectName: "a")
        let e2 = HookActivityEntry(event: .preToolUse, projectName: "b")
        let e3 = HookActivityEntry(event: .stop, projectName: "a")
        log.append(e1); log.append(e2); log.append(e3)
        #expect(log.stats(for: .preToolUse).todayCount == 2)
        #expect(log.stats(for: .stop).todayCount == 1)
        #expect(log.stats(for: .notification).todayCount == 0)
        #expect(log.stats(for: .preToolUse).lastFired == e2.firedAt)
    }
}
