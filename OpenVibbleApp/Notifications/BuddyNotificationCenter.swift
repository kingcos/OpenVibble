// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@preconcurrency import UserNotifications

/// Owns all local-notification plumbing for OpenVibble, including the
/// actionable "prompt" category that lets the user approve/deny a tool
/// permission right from the banner or the notification drawer.
///
/// Quick-action taps are routed back into the main app via the same App Group
/// + Darwin notification channel that the Live Activity AppIntents already
/// use (`LiveActivitySharedStore`). That way there is exactly one drain path
/// in `BridgeAppModel.drainPendingLiveActivityDecision` regardless of whether
/// the decision originated from the Dynamic Island, the lock-screen Live
/// Activity, or the notification banner — and a cold-launch from a
/// notification action keeps working even if `BridgeAppModel` hasn't finished
/// wiring up its Darwin observer when the delegate fires (the shared-store
/// record persists until the first heartbeat triggers a drain).
///
/// Hot path lives on the main thread: callers (`BridgeAppModel`) are
/// `@MainActor`, `UNUserNotificationCenter` delegate methods are documented
/// to fire on the main queue, and `OpenVibbleApp.init` runs on main. Keeping
/// the class `@MainActor`-isolated lets us safely mutate dedup state without
/// locks; the delegate-protocol conformance sits in a `nonisolated` extension
/// because the protocol signatures are not themselves MainActor-annotated.
@MainActor
final class BuddyNotificationCenter: NSObject {
    static let shared = BuddyNotificationCenter()

    // Immutable identifiers used by the delegate conformance (which lives in
    // a `nonisolated` extension) and by the notification payload. Marked
    // `nonisolated` so Swift 6 lets the delegate methods reference them
    // without hopping to MainActor.
    nonisolated static let promptCategoryId = "prompt"
    nonisolated static let approveActionId = "prompt.approve"
    nonisolated static let denyActionId = "prompt.deny"
    nonisolated fileprivate static let promptUserInfoIdKey = "promptID"

    private var lastPromptNotificationID: String?
    private var lastLevelNotified: UInt16 = 0

    private override init() {
        super.init()
    }

    /// Registers the actionable "prompt" category and installs this instance
    /// as the `UNUserNotificationCenter` delegate. Must be called from the
    /// app's launch path so action taps that cold-start the app still route
    /// through `userNotificationCenter(_:didReceive:withCompletionHandler:)`.
    func configure() {
        let approve = UNNotificationAction(
            identifier: Self.approveActionId,
            title: String(localized: "live.action.approve"),
            options: []
        )
        let deny = UNNotificationAction(
            identifier: Self.denyActionId,
            title: String(localized: "live.action.deny"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.promptCategoryId,
            actions: [approve, deny],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            return true
        }
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func notifyPromptIfNeeded(promptID: String, tool: String, enabled: Bool) {
        guard enabled else { return }
        guard promptID != lastPromptNotificationID else { return }
        lastPromptNotificationID = promptID

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.prompt.title")
        content.body = String(format: String(localized: "notification.prompt.body"), tool)
        content.sound = .default
        content.categoryIdentifier = Self.promptCategoryId
        content.userInfo = [Self.promptUserInfoIdKey: promptID]

        let request = UNNotificationRequest(
            identifier: "prompt.\(promptID)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyLevelUpIfNeeded(level: UInt16, enabled: Bool) {
        guard enabled else { return }
        guard level > lastLevelNotified else { return }
        lastLevelNotified = level

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.level.title")
        content.body = String(format: String(localized: "notification.level.body"), level)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "level.\(level)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Drops any pending/delivered local notification tied to a prompt id
    /// (e.g. after the user responds via Live Activity) so the quick-action
    /// buttons don't linger in the drawer for an already-answered prompt.
    func clearPromptNotifications(promptID: String) {
        guard !promptID.isEmpty else { return }
        let identifier = "prompt.\(promptID)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

// The `UNUserNotificationCenterDelegate` protocol isn't `@MainActor`, but the
// system invokes its methods on the main queue. We sit the conformance in a
// `nonisolated` extension that only touches thread-safe values
// (`response.notification.request.content.userInfo`, static string
// constants, and `LiveActivitySharedStore` which serializes its own writes
// through `UserDefaults` + `CFNotificationCenter`). This avoids forcing
// `@preconcurrency` on the whole class while still compiling under Swift 6.
extension BuddyNotificationCenter: UNUserNotificationCenterDelegate {
    /// Handle Approve/Deny action taps (and the default tap that launches the
    /// app). We deliberately mirror the Live Activity's shared-store + Darwin
    /// notification pattern instead of routing directly into `BridgeAppModel`:
    /// when the action cold-starts the app, `BridgeAppModel` may not have
    /// finished subscribing yet, but the shared-store record persists until
    /// `drainPendingLiveActivityDecision` runs on its first refresh.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let id = userInfo[BuddyNotificationCenter.promptUserInfoIdKey] as? String, !id.isEmpty else { return }

        let decision: LiveActivitySharedStore.Decision?
        switch response.actionIdentifier {
        case BuddyNotificationCenter.approveActionId: decision = .approve
        case BuddyNotificationCenter.denyActionId:    decision = .deny
        default:                                      decision = nil // default/dismiss: just open or ignore
        }
        guard let decision else { return }
        LiveActivitySharedStore.writePendingDecision(id: id, decision: decision)
    }

    /// Present the actionable banner while the app is foregrounded only if
    /// the user hasn't opted out. The setting default is `true`, so the
    /// quick-approve banner still surfaces unless they explicitly disable it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let allowed = (UserDefaults.standard.object(forKey: "buddy.foregroundNotificationsEnabled") as? Bool) ?? true
        if allowed {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([])
        }
    }
}
