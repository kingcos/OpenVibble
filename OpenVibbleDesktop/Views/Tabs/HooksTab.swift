// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import HookBridge

/// Combined "Overview + Hooks" tab. Used to be split across two tabs —
/// the Overview tab was removed and its content (pending approval banner,
/// connected-device info, and recent hook log) is now folded into this one.
struct HooksTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Most time-sensitive: if Claude Code is waiting on a
                // permission answer, surface it first.
                PendingApprovalBanner()

                // Hook registration status + register/unregister button.
                statusHeader

                // Device panel (from the old Overview tab).
                deviceSection

                // Grid of 10 hook event cards with counters.
                eventCardsGrid

                // Recent hook activity log — one big selectable Text block.
                recentSection
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

    private var deviceSection: some View {
        GroupBox(label: LText("desktop.device")) {
            VStack(alignment: .leading, spacing: 6) {
                deviceRow("desktop.device.name", state.connectedName ?? "—")
                let snap = state.statusSnapshot
                deviceRow("desktop.battery.pct", snap.batteryPct.map { "\($0)%" } ?? "—")
                deviceRow("desktop.stats.level", snap.statsLevel.map(String.init) ?? "—")
                deviceRow("desktop.stats.approved", snap.statsApproved.map(String.init) ?? "—")
            }
        }
    }

    private var eventCardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            EventCard(
                event: .permissionRequest,
                titleKey: "desktop.hooks.permissionRequest.title",
                descKey: "desktop.hooks.permissionRequest.desc",
                stats: state.hookActivity.stats(for: .permissionRequest)
            )
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
                event: .stopFailure,
                titleKey: "desktop.hooks.stopFailure.title",
                descKey: "desktop.hooks.stopFailure.desc",
                stats: state.hookActivity.stats(for: .stopFailure)
            )
            EventCard(
                event: .notification,
                titleKey: "desktop.hooks.notification.title",
                descKey: "desktop.hooks.notification.desc",
                stats: state.hookActivity.stats(for: .notification)
            )
            EventCard(
                event: .sessionStart,
                titleKey: "desktop.hooks.sessionStart.title",
                descKey: "desktop.hooks.sessionStart.desc",
                stats: state.hookActivity.stats(for: .sessionStart)
            )
            EventCard(
                event: .sessionEnd,
                titleKey: "desktop.hooks.sessionEnd.title",
                descKey: "desktop.hooks.sessionEnd.desc",
                stats: state.hookActivity.stats(for: .sessionEnd)
            )
            EventCard(
                event: .subagentStart,
                titleKey: "desktop.hooks.subagentStart.title",
                descKey: "desktop.hooks.subagentStart.desc",
                stats: state.hookActivity.stats(for: .subagentStart)
            )
            EventCard(
                event: .subagentStop,
                titleKey: "desktop.hooks.subagentStop.title",
                descKey: "desktop.hooks.subagentStop.desc",
                stats: state.hookActivity.stats(for: .subagentStop)
            )
        }
    }

    private var recentSection: some View {
        GroupBox(label: LText("desktop.overview.recentHooks")) {
            if state.hookActivity.recent.isEmpty {
                LText("desktop.hooks.empty").foregroundStyle(.secondary)
            } else {
                // One compound Text joined by newlines. Users can drag a
                // selection across multiple rows and ⌘C the whole span.
                // Per-field styling is preserved via Text + Text run
                // concatenation (monospaced event name, secondary project/
                // tool tags, decision-coloured label, tertiary timestamp).
                recentHooksText
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private func deviceRow(_ key: String, _ value: String) -> some View {
        HStack {
            LText(key).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
        }
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

    /// Builds one compound Text from the 20 most recent hook entries joined
    /// by newlines. Each row: "<time>  <event>  [project]  <tool>  <decision>".
    /// Returning a single Text makes selection span across rows.
    private var recentHooksText: Text {
        let timeFmt = Date.FormatStyle(date: .omitted, time: .standard)
        let entries = state.hookActivity.recent.prefix(20)
        return entries.enumerated().reduce(Text("")) { acc, pair in
            let (index, entry) = pair
            // Leading time column so rows line up under a mono font.
            var row = Text(entry.firedAt, format: timeFmt)
                .foregroundStyle(.tertiary)
                .monospaced()
            row = row + Text("  ") + Text(entry.event.rawValue).monospaced()
            if let project = entry.projectName {
                row = row + Text("  [\(project)]").foregroundStyle(.secondary)
            }
            if let tool = entry.toolName {
                row = row + Text("  \(tool)").foregroundStyle(.secondary)
            }
            if let decision = entry.decision {
                row = row + Text("  \(decision.rawValue)")
                    .fontWeight(.bold)
                    .foregroundStyle(color(for: decision))
            }
            return index == 0 ? row : acc + Text("\n") + row
        }
    }
}
