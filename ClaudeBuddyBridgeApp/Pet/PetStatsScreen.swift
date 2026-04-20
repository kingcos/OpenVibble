import SwiftUI
import BuddyPersona
import BuddyStats

struct PetStatsScreen: View {
    @ObservedObject var stats: PersonaStatsStore
    let charactersRootURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var confirmResetStats = false
    @State private var confirmDeleteChars = false
    @State private var infoMessage: String?

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
                Section("Danger Zone") {
                    Button(role: .destructive) {
                        confirmResetStats = true
                    } label: {
                        Label("Reset Pet Stats", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) {
                        confirmDeleteChars = true
                    } label: {
                        Label("Delete All Characters", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Pet Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset stats to zero?",
                isPresented: $confirmResetStats,
                titleVisibility: .visible
            ) {
                Button("Reset All Stats", role: .destructive) {
                    stats.reset()
                    infoMessage = "Stats reset."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Approvals, denials, level, tokens, and nap time will all return to zero. This cannot be undone.")
            }
            .confirmationDialog(
                "Delete all installed characters?",
                isPresented: $confirmDeleteChars,
                titleVisibility: .visible
            ) {
                Button("Delete All Characters", role: .destructive) {
                    let catalog = PersonaCatalog(rootURL: charactersRootURL)
                    let ok = catalog.deleteAll()
                    PersonaSelection.save(.asciiCat)
                    infoMessage = ok ? "Characters deleted." : "Delete failed."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All GIF packs pushed from Claude Desktop will be removed. You'll fall back to the built-in ASCII cat.")
            }
            .alert("Notice", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
                Button("OK", role: .cancel) { infoMessage = nil }
            } message: {
                Text(infoMessage ?? "")
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
