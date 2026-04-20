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
        ZStack {
            BuddyTheme.backgroundGradient(themePreset).ignoresSafeArea()

            VStack(spacing: 14) {
                M5DeviceShell {
                    screen
                }
                Text(persona.state.slug.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(BuddyTheme.palette(themePreset).highlight.opacity(0.85))
                    .tracking(3)
            }
            .padding(.vertical, 18)
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

    private var screen: some View {
        VStack(spacing: 6) {
            buddyRenderer
                .frame(maxWidth: .infinity)
                .frame(height: 92)

            headerRow

            Divider().background(Color.white.opacity(0.12))

            Group {
                if page == 0 {
                    statsPage
                } else {
                    howToPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var buddyRenderer: some View {
        switch resolvedPersona() {
        case .ascii:
            ASCIIBuddyView(state: persona.state)
                .scaleEffect(0.55)
        case .gif(let p):
            GIFView(persona: p, state: persona.state)
                .aspectRatio(contentMode: .fit)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 4) {
            Text(headerTitle)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Button {
                page = (page + 1) % pageCount
            } label: {
                Text("\(page + 1)/\(pageCount)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
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
        return VStack(alignment: .leading, spacing: 6) {
            row(label: "mood", pips: pipRow(filled: mood, total: 4, kind: .heart, color: moodColor(mood)))
            row(label: "fed", pips: pipRow(filled: fed, total: 10, kind: .dot, color: Color(red: 0.98, green: 0.68, blue: 0.35)))
            row(label: "energy", pips: pipRow(filled: energy, total: 5, kind: .bar, color: energyColor(energy)))

            HStack(spacing: 6) {
                Text("Lv \(s.level)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.98, green: 0.68, blue: 0.35), in: RoundedRectangle(cornerRadius: 3))
                Spacer()
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 1) {
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
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 44, alignment: .leading)
            pips
            Spacer(minLength: 0)
        }
    }

    private enum PipKind { case heart, dot, bar }

    private func pipRow(filled: Int, total: Int, kind: PipKind, color: Color) -> some View {
        HStack(spacing: kind == .dot ? 3 : 4) {
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
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(filled ? color : Color.white.opacity(0.35))
        case .dot:
            Circle()
                .fill(filled ? color : Color.clear)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: filled ? 0 : 1))
                .frame(width: 6, height: 6)
        case .bar:
            RoundedRectangle(cornerRadius: 1)
                .fill(filled ? color : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.white.opacity(0.35), lineWidth: filled ? 0 : 1))
                .frame(width: 10, height: 7)
        }
    }

    private func counterLine(_ label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .frame(width: 60, alignment: .leading)
            Text(value)
            Spacer(minLength: 0)
        }
        .font(.system(size: 10, weight: .regular, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.55))
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
        VStack(alignment: .leading, spacing: 6) {
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
            VStack(alignment: .leading, spacing: 1) {
                Text("idle = sleep")
                Text("tap 1/2 = next page")
            }
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.4))
            .padding(.top, 4)
        }
    }

    private func howToBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            ForEach(lines, id: \.self) { line in
                Text(" \(line)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
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
