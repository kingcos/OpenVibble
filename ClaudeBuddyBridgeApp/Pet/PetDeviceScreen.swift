import SwiftUI
import BuddyPersona
import BuddyStats
import BuddyUI
import NUSPeripheral

struct PetDeviceScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()
    @State private var tab: String = "stats"
    @AppStorage("buddy.showScanline") private var showScanline = true
    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.ownerName") private var ownerName: String = ""

    private let tabs: [TerminalTabBar.Tab] = [
        .init("stats", "STATS"),
        .init("howto", "HOWTO"),
        .init("live", "LIVE")
    ]

    var body: some View {
        ZStack {
            TerminalBackground(showScanline: showScanline)

            VStack(alignment: .leading, spacing: 10) {
                topBar
                statusStrip

                TerminalPanel("buddy --render") {
                    buddyRenderer
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 200, maxHeight: 240)
                }

                TerminalTabBar(tabs: tabs, selection: $tab)

                Group {
                    switch tab {
                    case "howto":
                        TerminalPanel("buddy --help") { howToContent }
                    case "live":
                        TerminalPanel("tail -f buddy.log", accent: .green) { liveContent }
                    default:
                        TerminalPanel("buddy --stats") { statsContent }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let ids = tabs.map(\.id)
                            guard let current = ids.firstIndex(of: tab) else { return }
                            if value.translation.width < 0 {
                                let next = min(current + 1, ids.count - 1)
                                if ids[next] != tab { withAnimation { tab = ids[next] } }
                            } else {
                                let prev = max(current - 1, 0)
                                if ids[prev] != tab { withAnimation { tab = ids[prev] } }
                            }
                        }
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 96)
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
        .onChange(of: model.prompt?.id) { _, newValue in
            if newValue != nil { withAnimation { tab = "live" } }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Text(headerTitle)
                .font(TerminalStyle.mono(13, weight: .semibold))
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            Text(persona.state.slug.uppercased())
                .font(TerminalStyle.mono(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.green.opacity(0.75))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 6, height: 6)
            Text(connectionLabel)
                .foregroundStyle(.green.opacity(0.8))
            Text("·")
                .foregroundStyle(.green.opacity(0.3))
            Text(model.snapshot.msg)
                .foregroundStyle(.green.opacity(0.65))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if model.prompt != nil {
                Text("⚠ prompt")
                    .foregroundStyle(.yellow)
            }
        }
        .font(TerminalStyle.mono(10))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    private var connectionColor: Color {
        switch model.connectionState {
        case .stopped: return .red.opacity(0.9)
        case .advertising: return .yellow
        case .connected: return .green
        }
    }

    private var connectionLabel: String {
        switch model.connectionState {
        case .stopped: return "ble:off"
        case .advertising: return "ble:adv"
        case .connected(let n): return "ble:conn×\(n)"
        }
    }

    private var headerTitle: String {
        let trimmedOwner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = petName.isEmpty ? "Buddy" : petName
        return "$ " + (trimmedOwner.isEmpty ? name : "\(trimmedOwner)'s \(name)")
    }

    // MARK: - Pet renderer

    @ViewBuilder
    private var buddyRenderer: some View {
        switch resolvedPersona() {
        case .ascii:
            ASCIIBuddyView(state: persona.state)
                .scaleEffect(1.0)
        case .gif(let p):
            GIFView(persona: p, state: persona.state)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 220)
        }
    }

    // MARK: - Stats page

    private var statsContent: some View {
        let s = stats.stats
        let mood = Int(s.moodTier)
        let fed = Int(s.fedProgress)
        let energy = Int(stats.energyTier())
        return VStack(alignment: .leading, spacing: 8) {
            pipRow(label: "mood",   filled: mood,   total: 4,  kind: .heart)
            pipRow(label: "fed",    filled: fed,    total: 10, kind: .dot)
            pipRow(label: "energy", filled: energy, total: 5,  kind: .bar)

            HStack(spacing: 8) {
                levelBadge(level: s.level)
                counterInline("approved", "\(s.approvals)")
                counterInline("denied",   "\(s.denials)")
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                counterLine("napped",   formatNap(s.napSeconds))
                counterLine("tokens",   formatTokens(s.tokens))
                counterLine("today",    formatTokens(stats.tokensToday))
            }
            .padding(.top, 2)
        }
    }

    // MARK: - HowTo page

    private var howToContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            howLine("mood", "approve fast → up")
            howLine("mood", "deny lots → down")
            howLine("fed",  "50K tokens = lv up")
            howLine("nrg",  "face-down naps to full")
            howLine("tip",  "idle → sleep")
            howLine("tip",  "tap STATS/HOWTO/LIVE")
        }
    }

    // MARK: - Live page (terminal content on pet screen)

    private var liveContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            line("ble",  model.bluetoothStateNote)
            line("adv",  model.advertisingNote)
            line("name", model.activeDisplayName)

            if model.transfer.isActive {
                Rectangle()
                    .fill(Color.green.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 2)
                Text("↓ \(model.transfer.characterName) :: \(model.transfer.currentFile)")
                    .font(TerminalStyle.mono(11, weight: .semibold))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: transferValue)
                    .tint(.green)
                Text("\(model.transfer.writtenBytes) / \(model.transfer.totalBytes) B")
                    .font(TerminalStyle.mono(10))
                    .foregroundStyle(.green.opacity(0.7))
            }

            Rectangle()
                .fill(Color.green.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 2)

            ForEach(liveLines.indices, id: \.self) { idx in
                Text(liveLines[idx])
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(.green.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let prompt = model.prompt {
                Rectangle()
                    .fill(Color.yellow.opacity(0.25))
                    .frame(height: 1)
                    .padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚠ \(prompt.tool) 待确认")
                        .font(TerminalStyle.mono(11, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                    if !prompt.hint.isEmpty {
                        Text(prompt.hint)
                            .font(TerminalStyle.mono(10))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        Button("允许") { model.respondPermission(.once) }
                            .buttonStyle(TerminalActionButtonStyle(foreground: .black, background: .green))
                        Button("拒绝") { model.respondPermission(.deny) }
                            .buttonStyle(TerminalActionButtonStyle(foreground: .white, background: .red.opacity(0.8)))
                    }
                }
            }
        }
    }

    private var transferValue: Double {
        guard model.transfer.totalBytes > 0 else { return 0 }
        return Double(model.transfer.writtenBytes) / Double(model.transfer.totalBytes)
    }

    private var liveLines: [String] {
        var lines = model.snapshot.entries.map { "[log]  \($0)" }
        if !model.snapshot.lastTurnPreview.isEmpty {
            lines.insert("[turn:\(model.snapshot.lastTurnRole)] \(model.snapshot.lastTurnPreview)", at: 0)
        }
        lines.append(contentsOf: model.recentEvents.prefix(20).map { "[evt]  \($0)" })
        return Array(lines.prefix(10))
    }

    // MARK: - Row helpers

    private enum PipKind { case heart, dot, bar }

    private func pipRow(label: String, filled: Int, total: Int, kind: PipKind) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(Color.green.opacity(0.65))
                .frame(width: 60, alignment: .leading)
            HStack(spacing: kind == .dot ? 4 : 5) {
                ForEach(0..<total, id: \.self) { i in
                    pipShape(kind: kind, filled: i < filled)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func pipShape(kind: PipKind, filled: Bool) -> some View {
        let fill = filled ? Color.green : Color.clear
        let stroke = Color.green.opacity(filled ? 0 : 0.45)
        switch kind {
        case .heart:
            Image(systemName: filled ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(filled ? Color.green : Color.green.opacity(0.35))
        case .dot:
            Circle()
                .fill(fill)
                .overlay(Circle().stroke(stroke, lineWidth: filled ? 0 : 1))
                .frame(width: 8, height: 8)
        case .bar:
            RoundedRectangle(cornerRadius: 1.5)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(stroke, lineWidth: filled ? 0 : 1))
                .frame(width: 14, height: 9)
        }
    }

    private func levelBadge(level: UInt8) -> some View {
        Text("Lv \(level)")
            .font(TerminalStyle.mono(12, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.green, in: RoundedRectangle(cornerRadius: 4))
    }

    private func counterInline(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(Color.green.opacity(0.6))
            Text(value)
                .foregroundStyle(Color.green)
        }
        .font(TerminalStyle.mono(11))
    }

    private func counterLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .frame(width: 80, alignment: .leading)
                .foregroundStyle(Color.green.opacity(0.6))
            Text(value)
                .foregroundStyle(Color.green.opacity(0.9))
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(12))
    }

    private func howLine(_ tag: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("[\(tag)]")
                .foregroundStyle(Color.green)
            Text(text)
                .foregroundStyle(Color.green.opacity(0.85))
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(12))
    }

    private func line(_ tag: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text("[\(tag)]")
                .foregroundStyle(Color.green)
            Text(text)
                .foregroundStyle(Color.green.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(12))
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
