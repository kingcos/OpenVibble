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
                        Text("RUN")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(context.state.running)")
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("WAIT")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(context.state.waiting)")
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.connection)
                            .font(.subheadline.weight(.semibold))
                        if context.state.promptPending {
                            Text("Permission pending")
                                .font(.caption)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Claude Buddy Bridge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Text("\(context.state.running)")
                    .font(.caption2)
            } compactTrailing: {
                Image(systemName: context.state.promptPending ? "exclamationmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(context.state.promptPending ? .yellow : .green)
            } minimal: {
                Image(systemName: "terminal")
            }
            .widgetURL(URL(string: "claudebuddy://status"))
            .keylineTint(.orange)
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let state: BuddyLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Buddy")
                    .font(.headline)
                Text(state.connection)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("R \(state.running)")
                Text("W \(state.waiting)")
                if state.promptPending {
                    Text("Prompt")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 8)
    }
}
