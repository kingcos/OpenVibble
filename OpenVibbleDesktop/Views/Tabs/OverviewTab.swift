import SwiftUI
import HookBridge

struct OverviewTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PendingApprovalBanner()

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
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(state.hookActivity.recent.prefix(5)) { entry in
                                HStack {
                                    Text(entry.event.rawValue)
                                        .font(.caption.weight(.semibold))
                                    if let p = entry.projectName {
                                        Text("[\(p)]").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(relative(entry.firedAt))
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
}
