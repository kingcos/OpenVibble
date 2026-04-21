import AppIntents
import Foundation

/// AppIntent invoked when the user taps the "允许 / Approve" button on the
/// Live Activity. Runs in the widget extension process, so it can't talk to
/// BLE directly — it records the decision into the shared App Group store
/// and posts a Darwin notification; the main app picks it up and calls
/// `respondPermission(.once)` on the actual BLE peripheral.
struct ApprovePromptIntent: AppIntent {
    static let title: LocalizedStringResource = "live.action.approve"
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = false

    @Parameter(title: "promptID") var promptID: String

    init() {
        self.promptID = ""
    }

    init(promptID: String) {
        self.promptID = promptID
    }

    func perform() async throws -> some IntentResult {
        LiveActivitySharedStore.writePendingDecision(id: promptID, decision: .approve)
        return .result()
    }
}

struct DenyPromptIntent: AppIntent {
    static let title: LocalizedStringResource = "live.action.deny"
    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = false

    @Parameter(title: "promptID") var promptID: String

    init() {
        self.promptID = ""
    }

    init(promptID: String) {
        self.promptID = promptID
    }

    func perform() async throws -> some IntentResult {
        LiveActivitySharedStore.writePendingDecision(id: promptID, decision: .deny)
        return .result()
    }
}
