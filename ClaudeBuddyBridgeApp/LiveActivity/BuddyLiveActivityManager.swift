import Foundation
@preconcurrency import ActivityKit
import NUSPeripheral
import BridgeRuntime

actor BuddyLiveActivityManager {
    private var activity: Activity<BuddyLiveActivityAttributes>?

    func startOrUpdate(state: NUSConnectionState, snapshot: BridgeSnapshot, hasPrompt: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = BuddyLiveActivityAttributes.ContentState(
            connection: connectionTitle(for: state),
            running: snapshot.running,
            waiting: snapshot.waiting,
            promptPending: hasPrompt
        )

        if let activity {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
            return
        }

        let attributes = BuddyLiveActivityAttributes(title: "Claude Buddy")
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil)
            )
        } catch {
            activity = nil
        }
    }

    func end() async {
        guard let activity else { return }
        let final = BuddyLiveActivityAttributes.ContentState(
            connection: "Offline",
            running: 0,
            waiting: 0,
            promptPending: false
        )
        await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
        self.activity = nil
    }

    private func connectionTitle(for state: NUSConnectionState) -> String {
        switch state {
        case .stopped:
            return "Stopped"
        case .advertising:
            return "Advertising"
        case .connected:
            return "Connected"
        }
    }
}
