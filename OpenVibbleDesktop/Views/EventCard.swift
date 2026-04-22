import SwiftUI
import HookBridge

struct EventCard: View {
    let event: HookEvent
    let titleKey: String
    let descKey: String
    let stats: HookEventStats

    @Environment(\.localizationBundle) private var bundle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                LText(titleKey).font(.headline)
                Spacer()
            }
            LText(descKey).font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack(spacing: 12) {
                Label {
                    Text(String(format: bundle.l("desktop.hooks.todayCount"), stats.todayCount))
                } icon: {
                    Image(systemName: "number.square")
                }
                .font(.caption)
                if let last = stats.lastFired {
                    Label {
                        let fmt = RelativeDateTimeFormatter()
                        Text(String(format: bundle.l("desktop.hooks.lastFired"), fmt.localizedString(for: last, relativeTo: Date())))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch event {
        case .preToolUse: return "shield"
        case .userPromptSubmit: return "text.bubble"
        case .stop: return "checkmark.seal"
        case .notification: return "bell"
        }
    }
}
