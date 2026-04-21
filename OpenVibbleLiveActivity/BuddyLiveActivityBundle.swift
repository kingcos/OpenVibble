import WidgetKit
import SwiftUI
@preconcurrency import ActivityKit

@main
struct BuddyLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        BuddyLiveActivityWidget()
    }
}

struct BuddyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuddyLiveActivityAttributes.self) { context in
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        MiniBuddyView(slug: context.state.personaSlug, size: 28)
                        Text("OpenVibble")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            countLabel("R", context.state.running)
                            countLabel("W", context.state.waiting)
                        }
                        Text(context.state.connection)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.promptPending {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(context.state.messagePreview ?? String(localized: "live.alert.body"))
                                .font(.caption.monospaced())
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                MiniBuddyView(slug: context.state.personaSlug, size: 16)
            } compactTrailing: {
                if context.state.promptPending {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                } else {
                    Text("\(context.state.running)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.green)
                }
            } minimal: {
                MiniBuddyView(slug: context.state.personaSlug, size: 16)
            }
            .widgetURL(URL(string: "openvibble://status"))
            .keylineTint(.orange)
        }
    }

    private func countLabel(_ tag: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Text(tag)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let state: BuddyLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            MiniBuddyView(slug: state.personaSlug, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenVibble")
                    .font(.headline)
                if state.promptPending {
                    Text(state.messagePreview ?? String(localized: "live.alert.body"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.yellow)
                        .lineLimit(2)
                } else {
                    Text(state.connection)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("R \(state.running)")
                Text("W \(state.waiting)")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Miniature pet renderer — maps a PersonaState slug to a glyph that reads at
/// small sizes on the Dynamic Island and lock screen.
struct MiniBuddyView: View {
    let slug: String
    let size: CGFloat

    var body: some View {
        Text(glyph)
            .font(.system(size: size))
            .frame(width: size + 4, height: size + 4)
            .minimumScaleFactor(0.6)
    }

    private var glyph: String {
        switch slug {
        case "sleep": return "😴"
        case "busy": return "⚡️"
        case "attention": return "❗️"
        case "celebrate": return "🎉"
        case "dizzy": return "💫"
        case "heart": return "💚"
        case "idle": return "🙂"
        default: return "🙂"
        }
    }
}
