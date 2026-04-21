import SwiftUI
import BuddyPersona
import BuddyStats
import BuddyUI
import BridgeRuntime
import NUSPeripheral

/// Pet screen framed as the M5 handheld's LCD. Mirrors the layout from
/// `h5-demo.html` (pet-view): header + sprite + mood/fed/energy rows + Lv
/// badge + `approved/denied/napped/tokens/today` metric block.
struct PetDeviceScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()
    @State private var tab: String = "stats"
    /// Sub-page index inside the INFO tab (6 pages, matches firmware INFO_PAGES).
    @State private var infoPage: Int = 0
    /// When the current prompt first arrived; drives the "Xs" waited counter in
    /// the approval banner, matching firmware `drawApprovalPanel`.
    @State private var promptArrivedAt: Date? = nil
    /// Ticks every second while a prompt is pending so the waited-time text
    /// refreshes. Reset to 0 when the prompt clears.
    @State private var promptTick: Int = 0
    private let appStart = Date()
    private let promptTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("buddy.showScanline") private var showScanline = true
    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.ownerName") private var ownerName: String = ""

    /// STATS/HOWTO match firmware's two PET pages. LIVE surfaces the BLE log
    /// + approval buttons (firmware shows those on NORMAL). INFO holds the
    /// six-page info carousel from firmware `DISP_INFO`.
    private let tabs: [TerminalTabBar.Tab] = [
        .init("stats", "STATS"),
        .init("howto", "HOWTO"),
        .init("live",  "LIVE"),
        .init("info",  "INFO")
    ]

    var body: some View {
        ZStack {
            TerminalBackground(showScanline: showScanline)

            VStack(alignment: .leading, spacing: 12) {
                statusStrip
                DeviceShell {
                    lcdContent
                }
                .aspectRatio(0.62, contentMode: .fit)
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)

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
            if newValue != nil {
                promptArrivedAt = Date()
                promptTick = 0
                withAnimation { tab = "live" }
            } else {
                promptArrivedAt = nil
            }
        }
        .onReceive(promptTimer) { _ in
            if promptArrivedAt != nil { promptTick &+= 1 }
        }
    }

    // MARK: - Status strip (above the device shell)

    private var statusStrip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 6, height: 6)
            Text(connectionLabel)
                .foregroundStyle(TerminalStyle.ink)
            Text("·")
                .foregroundStyle(TerminalStyle.inkFaint)
            Text(model.snapshot.msg)
                .foregroundStyle(TerminalStyle.inkDim)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if model.prompt != nil {
                Text("⚠ prompt")
                    .foregroundStyle(TerminalStyle.accent)
            }
        }
        .font(TerminalStyle.mono(10))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(TerminalStyle.lcdPanel.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(TerminalStyle.inkDim.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - LCD content (inside device shell)

    @ViewBuilder
    private var lcdContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            petHeader
            TerminalTabBar(tabs: tabs, selection: $tab)
            Divider()
                .background(TerminalStyle.lcdDivider)

            Group {
                switch tab {
                case "howto": howToContent
                case "live":  liveContent
                case "info":  infoContent
                default:      statsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottom) {
                if let prompt = model.prompt {
                    approvalBanner(prompt)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        // Inside INFO, horizontal swipe pages through the 6 info screens.
                        if tab == "info" {
                            let count = Self.infoPages.count
                            if value.translation.width < 0 {
                                withAnimation { infoPage = (infoPage + 1) % count }
                            } else {
                                withAnimation { infoPage = (infoPage - 1 + count) % count }
                            }
                            return
                        }
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
        }
    }

    private var petHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(petHeaderName)
                .font(TerminalStyle.mono(12, weight: .semibold))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Text(persona.state.slug.uppercased())
                .font(TerminalStyle.mono(9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(TerminalStyle.inkDim)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .overlay(
                    Capsule().stroke(TerminalStyle.inkDim.opacity(0.6), lineWidth: 1)
                )
            Text(pageIndicator)
                .font(TerminalStyle.mono(10, weight: .semibold))
                .foregroundStyle(TerminalStyle.inkDim)
        }
    }

    private var petHeaderName: String {
        let trimmedOwner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = petName.isEmpty ? "Buddy" : petName
        return trimmedOwner.isEmpty ? name : "\(trimmedOwner)'s \(name)"
    }

    private var pageIndicator: String {
        if tab == "info" {
            return "\(infoPage + 1)/\(Self.infoPages.count)"
        }
        let ids = tabs.map(\.id)
        if let idx = ids.firstIndex(of: tab) {
            return "\(idx + 1)/\(ids.count)"
        }
        return "1/\(ids.count)"
    }

    private var connectionColor: Color {
        switch model.connectionState {
        case .stopped: return TerminalStyle.bad
        case .advertising: return TerminalStyle.accentSoft
        case .connected: return TerminalStyle.good
        }
    }

    private var connectionLabel: String {
        switch model.connectionState {
        case .stopped: return "ble:off"
        case .advertising: return "ble:adv"
        case .connected(let n): return "ble:conn×\(n)"
        }
    }

    // MARK: - Stats page (mirrors h5 `pet-view`)

    @ViewBuilder
    private var statsContent: some View {
        let s = stats.stats
        let mood = Int(s.moodTier)
        let fed = Int(s.fedProgress)
        let energy = Int(stats.energyTier())

        VStack(alignment: .leading, spacing: 6) {
            // Sprite area at the top of the LCD, constrained like the h5 `pet-sprite`.
            buddyRenderer
                .frame(maxWidth: .infinity)
                .frame(height: 90)

            pipRow(label: "mood")   { PetIndicator.MoodRow(tier: mood) }
            pipRow(label: "fed")    { PetIndicator.FedRow(filled: fed) }
            pipRow(label: "energy") { PetIndicator.EnergyRow(tier: energy) }

            PetIndicator.LevelBadge(level: s.level)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                metricLine("approved", "\(s.approvals)")
                metricLine("denied",   "\(s.denials)")
                metricLine("napped",   formatNap(s.napSeconds))
                metricLine("tokens",   formatTokens(s.tokens))
                metricLine("today",    formatTokens(stats.tokensToday))
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Info carousel (mirrors firmware DISP_INFO / h5 `INFO_PAGES = 6`)

    private static let infoPages: [String] = [
        "ABOUT", "BUTTONS", "CLAUDE", "DEVICE", "BLE", "CREDITS"
    ]

    @ViewBuilder
    private var infoContent: some View {
        let page = Self.infoPages[infoPage]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(page)
                    .font(TerminalStyle.mono(12, weight: .bold))
                    .foregroundStyle(TerminalStyle.accent)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<Self.infoPages.count, id: \.self) { i in
                        Circle()
                            .fill(i == infoPage ? TerminalStyle.accent : TerminalStyle.inkDim.opacity(0.5))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            Divider().background(TerminalStyle.lcdDivider)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(infoLines(for: page), id: \.self) { line in
                    Text(line)
                        .font(TerminalStyle.mono(11))
                        .foregroundStyle(TerminalStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button {
                    withAnimation { infoPage = (infoPage - 1 + Self.infoPages.count) % Self.infoPages.count }
                } label: {
                    Text("◀")
                }
                .buttonStyle(TerminalHeaderButtonStyle())

                Spacer()

                Text("swipe ↔ to page")
                    .font(TerminalStyle.mono(9))
                    .foregroundStyle(TerminalStyle.inkFaint)

                Spacer()

                Button {
                    withAnimation { infoPage = (infoPage + 1) % Self.infoPages.count }
                } label: {
                    Text("▶")
                }
                .buttonStyle(TerminalHeaderButtonStyle())
            }
        }
    }

    private func infoLines(for page: String) -> [String] {
        switch page {
        case "ABOUT":
            return [
                "Claude Buddy Bridge",
                "iPhone ↔ Claude Desktop",
                "BLE NUS bridge + pet sim",
                "tap LIVE: approve / deny"
            ]
        case "BUTTONS":
            return [
                "tap tabs to switch page",
                "swipe ↔ to next/prev",
                "toggle bottom: PET / TERM",
                "gear top-right = settings"
            ]
        case "CLAUDE":
            return [
                "sessions: \(model.snapshot.total)",
                "running:  \(model.snapshot.running)",
                "waiting:  \(model.snapshot.waiting)",
                "state:    \(persona.state.slug)",
                "tokd:     \(model.snapshot.tokensToday)"
            ]
        case "DEVICE":
            let uptime = Int(Date().timeIntervalSince(appStart))
            return [
                "uptime:   \(formatUptime(uptime))",
                "scanline: \(showScanline ? "on" : "off")",
                "owner:    \(ownerName.isEmpty ? "—" : ownerName)",
                "pet:      \(petName.isEmpty ? "Buddy" : petName)"
            ]
        case "BLE":
            return [
                "link:  \(connectionLabel)",
                "adv:   \(model.advertisingNote)",
                "name:  \(model.activeDisplayName)",
                "NUS:   6e400001-...-e9d6"
            ]
        case "CREDITS":
            return [
                "Felix Rieseberg — idea",
                "anthropics/",
                "  claude-desktop-buddy",
                "iOS bridge: kingcos",
                "MIT-licensed"
            ]
        default:
            return []
        }
    }

    private func formatUptime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds / 60) % 60
        let s = seconds % 60
        if h > 0 { return String(format: "%dh%02dm", h, m) }
        if m > 0 { return String(format: "%dm%02ds", m, s) }
        return "\(s)s"
    }

    // MARK: - How-to page

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

    // MARK: - Live page (BLE log + approval buttons)

    private var liveContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            line("ble",  model.bluetoothStateNote)
            line("adv",  model.advertisingNote)
            line("name", model.activeDisplayName)

            if model.transfer.isActive {
                Rectangle()
                    .fill(TerminalStyle.inkDim.opacity(0.35))
                    .frame(height: 1)
                    .padding(.vertical, 2)
                Text("↓ \(model.transfer.characterName) :: \(model.transfer.currentFile)")
                    .font(TerminalStyle.mono(11, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressView(value: transferValue)
                    .tint(TerminalStyle.ink)
                Text("\(model.transfer.writtenBytes) / \(model.transfer.totalBytes) B")
                    .font(TerminalStyle.mono(10))
                    .foregroundStyle(TerminalStyle.inkDim)
            }

            Rectangle()
                .fill(TerminalStyle.inkDim.opacity(0.35))
                .frame(height: 1)
                .padding(.vertical, 2)

            ForEach(liveLines.indices, id: \.self) { idx in
                Text(liveLines[idx])
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.ink.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Prompt overlay banner — mirrors firmware `drawApprovalPanel`:
    /// "approve? Xs" line (orange after 10s), tool name, hint, A/B hints,
    /// plus tappable approve/deny buttons.
    private func approvalBanner(_ prompt: PromptRequest) -> some View {
        let waited = promptArrivedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        _ = promptTick // bind to trigger re-render each second
        let timerColor: Color = waited >= 10 ? TerminalStyle.accent : TerminalStyle.inkDim
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("approve? \(waited)s")
                    .font(TerminalStyle.mono(10, weight: .semibold))
                    .foregroundStyle(timerColor)
                Spacer(minLength: 0)
                Text("A:approve  B:deny")
                    .font(TerminalStyle.mono(9))
                    .foregroundStyle(TerminalStyle.inkFaint)
            }
            Text(prompt.tool)
                .font(TerminalStyle.mono(14, weight: .bold))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            if !prompt.hint.isEmpty {
                Text(prompt.hint)
                    .font(TerminalStyle.mono(10))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            HStack(spacing: 6) {
                Button("allow") { model.respondPermission(.once) }
                    .buttonStyle(TerminalActionButtonStyle(
                        foreground: .white,
                        background: TerminalStyle.good
                    ))
                Button("deny") { model.respondPermission(.deny) }
                    .buttonStyle(TerminalActionButtonStyle(
                        foreground: .white,
                        background: TerminalStyle.bad
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(TerminalStyle.lcdBg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(TerminalStyle.lcdDivider)
                .frame(height: 1)
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
        return Array(lines.prefix(6))
    }

    // MARK: - Sprite

    @ViewBuilder
    private var buddyRenderer: some View {
        switch resolvedPersona() {
        case .ascii:
            ASCIIBuddyView(state: persona.state)
                .scaleEffect(0.65)
        case .gif(let p):
            GIFView(persona: p, state: persona.state)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 90)
        }
    }

    // MARK: - Row helpers

    private func pipRow<Indicator: View>(label: String, @ViewBuilder content: () -> Indicator) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.inkDim)
                .frame(width: 52, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private func metricLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(TerminalStyle.inkDim)
            Text(value)
                .foregroundStyle(TerminalStyle.ink)
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(11))
    }

    private func howLine(_ tag: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("[\(tag)]")
                .foregroundStyle(TerminalStyle.accent)
            Text(text)
                .foregroundStyle(TerminalStyle.ink)
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(12))
    }

    private func line(_ tag: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text("[\(tag)]")
                .foregroundStyle(TerminalStyle.ink)
            Text(text)
                .foregroundStyle(TerminalStyle.inkDim)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(11))
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
