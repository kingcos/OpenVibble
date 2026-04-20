import Foundation
@preconcurrency import ActivityKit

struct BuddyLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var connection: String
        var running: Int
        var waiting: Int
        var promptPending: Bool
    }

    var title: String
}
