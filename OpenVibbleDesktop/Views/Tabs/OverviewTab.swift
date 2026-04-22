// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import HookBridge

struct OverviewTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PendingApprovalBanner()
                if case .notRegistered = state.registrationStatus {
                    hooksCTA
                }

                GroupBox(label: LText("desktop.device")) {
                    VStack(alignment: .leading, spacing: 6) {
                        row("desktop.device.name", state.connectedName ?? "—")
                        let snap = state.statusSnapshot
                        row("desktop.battery.pct", snap.batteryPct.map { "\($0)%" } ?? "—")
                        row("desktop.stats.level", snap.statsLevel.map(String.init) ?? "—")
                        row("desktop.stats.approved", snap.statsApproved.map(String.init) ?? "—")
                    }
                }

                GroupBox(label: LText("desktop.overview.recentHooks")) {
                    if state.hookActivity.recent.isEmpty {
                        LText("desktop.hooks.empty").foregroundStyle(.secondary)
                    } else {
                        // All rows are concatenated into ONE Text so selection
                        // can sweep across rows. Each per-field Text keeps its
                        // own style via Text("…").font(…).foregroundStyle(…)
                        // because Text + Text preserves styled runs.
                        recentHooksText
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(16)
        }
    }

    private var hooksCTA: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                LText("desktop.overview.hooksCTA.title").font(.headline)
                Spacer()
            }
            LText("desktop.overview.hooksCTA.desc")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(action: { state.registerHooks() }) {
                    LText("desktop.hooks.register")
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            LText(key).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
        }
    }

    private func relative(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    /// Builds one compound Text from the 5 most recent hook entries, joined
    /// by newlines, so the whole thing is a single selection unit. Per-field
    /// styling (bold event name, secondary project tag, tertiary timestamp)
    /// is preserved via Text + Text run concatenation.
    private var recentHooksText: Text {
        let entries = Array(state.hookActivity.recent.prefix(5))
        var line = 0
        return entries.reduce(Text("")) { acc, entry in
            var row = Text(entry.event.rawValue).fontWeight(.semibold)
            if let p = entry.projectName {
                row = row + Text(" [\(p)]").foregroundStyle(.secondary)
            }
            row = row + Text("  ") + Text(relative(entry.firedAt)).foregroundStyle(.tertiary)
            defer { line += 1 }
            return line == 0 ? row : acc + Text("\n") + row
        }
    }
}
