import SwiftUI
import HookBridge

struct HooksTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusHeader

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    EventCard(
                        event: .preToolUse,
                        titleKey: "desktop.hooks.preToolUse.title",
                        descKey: "desktop.hooks.preToolUse.desc",
                        stats: state.hookActivity.stats(for: .preToolUse)
                    )
                    EventCard(
                        event: .userPromptSubmit,
                        titleKey: "desktop.hooks.userPromptSubmit.title",
                        descKey: "desktop.hooks.userPromptSubmit.desc",
                        stats: state.hookActivity.stats(for: .userPromptSubmit)
                    )
                    EventCard(
                        event: .stop,
                        titleKey: "desktop.hooks.stop.title",
                        descKey: "desktop.hooks.stop.desc",
                        stats: state.hookActivity.stats(for: .stop)
                    )
                    EventCard(
                        event: .notification,
                        titleKey: "desktop.hooks.notification.title",
                        descKey: "desktop.hooks.notification.desc",
                        stats: state.hookActivity.stats(for: .notification)
                    )
                }

                GroupBox(label: LText("desktop.overview.recentHooks")) {
                    if state.hookActivity.recent.isEmpty {
                        LText("desktop.hooks.empty").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(state.hookActivity.recent.prefix(20)) { entry in
                                HStack(spacing: 8) {
                                    Text(entry.event.rawValue).font(.caption.monospaced())
                                    if let project = entry.projectName {
                                        Text("[\(project)]").font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let tool = entry.toolName {
                                        Text(tool).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let decision = entry.decision {
                                        Text(decision.rawValue)
                                            .font(.caption.bold())
                                            .foregroundStyle(color(for: decision))
                                    }
                                    Spacer()
                                    Text(entry.firedAt, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var statusHeader: some View {
        HStack {
            switch state.registrationStatus {
            case .registered:
                Label {
                    LText("desktop.hooks.status.registered")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            case .partiallyRegistered:
                Label {
                    LText("desktop.hooks.status.partial")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            case .notRegistered:
                Label {
                    LText("desktop.hooks.status.notRegistered")
                } icon: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            Spacer()
            if isRegistered {
                Button(action: { state.unregisterHooks() }) { LText("desktop.hooks.unregister") }
            } else {
                Button(action: { state.registerHooks() }) { LText("desktop.hooks.register") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 4)
    }

    private var isRegistered: Bool {
        if case .notRegistered = state.registrationStatus { return false }
        return true
    }

    private func color(for d: HookEvent.PermissionDecisionKind) -> Color {
        switch d {
        case .allow: return .green
        case .deny: return .red
        case .ask: return .orange
        }
    }
}
