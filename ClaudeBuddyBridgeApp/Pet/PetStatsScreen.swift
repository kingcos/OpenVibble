import SwiftUI
import BuddyPersona
import BuddyStats

struct PetStatsScreen: View {
    @ObservedObject var stats: PersonaStatsStore
    let charactersRootURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var confirmResetStats = false
    @State private var confirmDeleteChars = false
    @State private var infoMessage: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row(labelKey: "pet.level", value: "\(stats.stats.level)")
                    row(labelKey: "pet.tokens", value: formatTokens(stats.stats.tokens))
                    row(labelKey: "pet.fed", value: "\(stats.stats.fedProgress)/10")
                } header: {
                    Text("pet.section.progress")
                }

                Section {
                    row(labelKey: "pet.approvals", value: "\(stats.stats.approvals)")
                    row(labelKey: "pet.denials", value: "\(stats.stats.denials)")
                    row(labelKey: "pet.medianResponse", value: formatSeconds(stats.stats.medianVelocitySeconds))
                } header: {
                    Text("pet.section.responses")
                }

                Section {
                    row(labelKey: "pet.totalNap", value: formatDuration(stats.stats.napSeconds))
                    row(labelKey: "pet.energy", value: "\(stats.energyTier())/5")
                    row(labelKey: "pet.mood", value: "\(stats.stats.moodTier)/4")
                } header: {
                    Text("pet.section.rest")
                }

                Section {
                    Button(role: .destructive) {
                        confirmResetStats = true
                    } label: {
                        Label("pet.reset", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) {
                        confirmDeleteChars = true
                    } label: {
                        Label("pet.delete", systemImage: "trash")
                    }
                } header: {
                    Text("pet.section.danger")
                }
            }
            .scrollContentBackground(.hidden)
            .background(BuddyTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("pet.stats.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
            .confirmationDialog(
                Text("pet.reset.confirm"),
                isPresented: $confirmResetStats,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    stats.reset()
                    infoMessage = "pet.stats.resetOk"
                } label: { Text("pet.reset.doIt") }
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text("pet.reset.message")
            }
            .confirmationDialog(
                Text("pet.delete.confirm"),
                isPresented: $confirmDeleteChars,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    let catalog = PersonaCatalog(rootURL: charactersRootURL)
                    let ok = catalog.deleteAll()
                    PersonaSelection.save(PersonaSelection.defaultSpecies)
                    infoMessage = ok ? "pet.stats.deleteOk" : "pet.stats.deleteFail"
                } label: { Text("pet.delete.doIt") }
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text("pet.delete.message")
            }
            .alert("common.notice", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
                Button("common.ok", role: .cancel) { infoMessage = nil }
            } message: {
                if let m = infoMessage { Text(m) }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func row(labelKey: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(labelKey)
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
