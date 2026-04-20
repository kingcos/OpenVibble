import SwiftUI
import BuddyStats

struct PetStatsScreen: View {
    @ObservedObject var stats: PersonaStatsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Progress") {
                    row(label: "Level", value: "\(stats.stats.level)")
                    row(label: "Tokens", value: formatTokens(stats.stats.tokens))
                    row(label: "Fed", value: "\(stats.stats.fedProgress)/10")
                }
                Section("Responses") {
                    row(label: "Approvals", value: "\(stats.stats.approvals)")
                    row(label: "Denials", value: "\(stats.stats.denials)")
                    row(label: "Median Response", value: formatSeconds(stats.stats.medianVelocitySeconds))
                }
                Section("Rest") {
                    row(label: "Total Nap", value: formatDuration(stats.stats.napSeconds))
                    row(label: "Energy", value: "\(stats.energyTier())/5")
                    row(label: "Mood", value: "\(stats.stats.moodTier)/4")
                }
            }
            .navigationTitle("Pet Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func formatTokens(_ tokens: UInt32) -> String {
        if tokens >= 1_000_000 { return String(format: "%.1fM", Double(tokens) / 1_000_000) }
        if tokens >= 1_000 { return String(format: "%.1fK", Double(tokens) / 1_000) }
        return "\(tokens)"
    }

    private func formatSeconds(_ seconds: UInt16) -> String {
        if seconds == 0 { return "—" }
        if seconds < 60 { return "\(seconds)s" }
        return String(format: "%dm %ds", seconds / 60, seconds % 60)
    }

    private func formatDuration(_ seconds: UInt32) -> String {
        if seconds == 0 { return "—" }
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        return String(format: "%dh %dm", m / 60, m % 60)
    }
}
