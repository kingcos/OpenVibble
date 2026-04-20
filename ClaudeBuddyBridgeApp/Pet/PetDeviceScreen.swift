import SwiftUI
import BuddyPersona
import BuddyStats
import BuddyUI

struct PetDeviceScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()
    @State private var page: Int = 0
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue
    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.ownerName") private var ownerName: String = ""

    private let pageCount = 2

    var body: some View {
        let palette = BuddyTheme.palette(themePreset)
        ZStack {
            palette.screen.ignoresSafeArea()

            VStack(spacing: 0) {
                // Buddy renderer (top half)
                buddyRenderer
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 24)

                // Header row
                headerRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Body (stats or howto)
                Group {
                    if page == 0 {
                        statsPage
                    } else {
                        howToPage
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 260)

                Text(persona.state.slug.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.highlight.opacity(0.85))
                    .tracking(3)
                    .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(.top, 44) // room for gear button
            .padding(.bottom, 100) // room for mechanical switch
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: reloadInstalled)
        .onChange(of: model.lastInstalledCharacter) { _, newValue in
            reloadInstalled()
            if let newValue {
                selection = .installed(name: newValue)
                PersonaSelection.save(selection)
            }
        }
    }

    @ViewBuilder
    private var buddyRenderer: some View {
        switch resolvedPersona() {
        case .ascii:
            ASCIIBuddyView(state: persona.state)
                .scaleEffect(1.0)
        case .gif(let p):
            GIFView(persona: p, state: persona.state)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 240)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(headerTitle)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Button {
                page = (page + 1) % pageCount
            } label: {
                Text("\(page + 1)/\(pageCount)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("pet.a11y.nextPage"))
        }
    }

    private var headerTitle: String {
        let trimmedOwner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = petName.isEmpty ? "Buddy" : petName
        return trimmedOwner.isEmpty ? name : "\(trimmedOwner)'s \(name)"
    }

    // MARK: - Stats page (ESP32 replica)

    private var statsPage: some View {
        let s = stats.stats
        let mood = Int(s.moodTier)
        let fed = Int(s.fedProgress)
        let energy = Int(stats.energyTier())
        return VStack(alignment: .leading, spacing: 10) {
            row(label: "mood", pips: pipRow(filled: mood, total: 4, kind: .heart, color: moodColor(mood)))
            row(label: "fed", pips: pipRow(filled: fed, total: 10, kind: .dot, color: Color(red: 0.98, green: 0.68, blue: 0.35)))
            row(label: "energy", pips: pipRow(filled: energy, total: 5, kind: .bar, color: energyColor(energy)))

            HStack(spacing: 6) {
                Text("Lv \(s.level)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.98, green: 0.68, blue: 0.35), in: RoundedRectangle(cornerRadius: 4))
                Spacer()
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                counterLine("approved", value: "\(s.approvals)")
                counterLine("denied",   value: "\(s.denials)")
                counterLine("napped",   value: formatNap(s.napSeconds))
                counterLine("tokens",   value: formatTokens(s.tokens))
                counterLine("today",    value: formatTokens(stats.tokensToday))
            }
            .padding(.top, 2)
        }
    }

    private func row(label: String, pips: some View) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 60, alignment: .leading)
            pips
            Spacer(minLength: 0)
        }
    }

    private enum PipKind { case heart, dot, bar }

    private func pipRow(filled: Int, total: Int, kind: PipKind, color: Color) -> some View {
        HStack(spacing: kind == .dot ? 4 : 5) {
            ForEach(0..<total, id: \.self) { i in
                pipShape(kind: kind, filled: i < filled, color: color)
            }
        }
    }

    @ViewBuilder
    private func pipShape(kind: PipKind, filled: Bool, color: Color) -> some View {
        switch kind {
        case .heart:
            Image(systemName: filled ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(filled ? color : Color.white.opacity(0.35))
        case .dot:
            Circle()
                .fill(filled ? color : Color.clear)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: filled ? 0 : 1))
                .frame(width: 8, height: 8)
        case .bar:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(filled ? color : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(Color.white.opacity(0.35), lineWidth: filled ? 0 : 1))
                .frame(width: 14, height: 9)
        }
    }

    private func counterLine(_ label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .frame(width: 86, alignment: .leading)
            Text(value)
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.62))
    }

    private func moodColor(_ mood: Int) -> Color {
        if mood >= 3 { return Color(red: 1.0, green: 0.35, blue: 0.45) }
        if mood >= 2 { return Color(red: 1.0, green: 0.55, blue: 0.25) }
        return Color.white.opacity(0.55)
    }

    private func energyColor(_ energy: Int) -> Color {
        if energy >= 4 { return Color(red: 0.15, green: 0.85, blue: 1.0) }
        if energy >= 2 { return Color(red: 1.0, green: 0.85, blue: 0.0) }
        return Color(red: 1.0, green: 0.55, blue: 0.25)
    }

    private func formatTokens(_ v: UInt32) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", Double(v) / 1_000) }
        return "\(v)"
    }

    private func formatNap(_ seconds: UInt32) -> String {
        let h = seconds / 3600
        let m = (seconds / 60) % 60
        return String(format: "%luh%02lum", h, m)
    }

    // MARK: - HowTo page

    private var howToPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            howToBlock(title: "MOOD", lines: [
                "approve fast = up",
                "deny lots = down"
            ])
            howToBlock(title: "FED", lines: [
                "50K tokens =",
                "level up + confetti"
            ])
            howToBlock(title: "ENERGY", lines: [
                "face-down to nap",
                "refills to full"
            ])
            VStack(alignment: .leading, spacing: 2) {
                Text("idle = sleep")
                Text("tap 1/2 = next page")
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.4))
            .padding(.top, 6)
        }
    }

    private func howToBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            ForEach(lines, id: \.self) { line in
                Text(" \(line)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
    }

    // MARK: - Resolution

    private enum ResolvedPersona {
        case ascii
        case gif(InstalledPersona)
    }

    private func resolvedPersona() -> ResolvedPersona {
        switch selection {
        case .asciiCat:
            return .ascii
        case .builtin(let name):
            if let match = builtin.first(where: { $0.name == name }) { return .gif(match) }
            return .ascii
        case .installed(let name):
            if let match = installed.first(where: { $0.name == name }) { return .gif(match) }
            return .ascii
        }
    }

    private func reloadInstalled() {
        let catalog = PersonaCatalog(rootURL: model.charactersRootURL)
        installed = catalog.listInstalled()
        selection = PersonaSelection.load()
    }
}
