import Foundation
import UserNotifications

@MainActor
final class BuddyNotificationCenter {
    static let shared = BuddyNotificationCenter()

    private var lastPromptNotificationID: String?
    private var lastLevelNotified: UInt16 = 0

    private init() {}

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
}
