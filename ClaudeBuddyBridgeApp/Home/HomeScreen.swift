import SwiftUI
import UIKit
import CoreBluetooth
import BuddyPersona
import BuddyStats
import BuddyUI
import BridgeRuntime
import NUSPeripheral
import BuddyProtocol

/// Main screen — handheld-style "the phone screen is the dev-board screen".
///
/// Layout:
///   ┌──────────────────────────┐
///   │ ◉ BLE:conn          ⚙    │   status indicator + settings
///   │                          │
///   │        [pet area]        │   fixed 42% height so content below
///   │                          │   never reflows when stats change
///   ├──────────────────────────┤
///   │  NORMAL / PET / INFO body│   mode switches, layout stable
///   ├──────────────────────────┤
///   │  A    B         [≣ Log]  │   handheld bottom buttons
///   └──────────────────────────┘
///
/// A short-press cycles NORMAL → PET → INFO. B short-presses:
///   - NORMAL with prompt: deny
///   - PET / INFO: next internal page
///   - otherwise: ignored
/// Horizontal swipe also pages PET/INFO.
struct HomeScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var mode: DisplayMode = .normal
    @State private var petPage: Int = 0
    @State private var infoPage: Int = 0
    @State private var showSettings = false
    @State private var showLogs = false
    @State private var promptArrivedAt: Date?
    @State private var promptTick: Int = 0

    @AppStorage("bridge.displayName") private var persistedDisplayName = ""
    @AppStorage("bridge.autoStartBLE") private var autoStartBLE = true
    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.showScanline") private var showScanline = true

    private let appStart = Date()
    private let promptTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum DisplayMode: Int {
        case normal, pet, info
        var next: DisplayMode {
            switch self {
            case .normal: return .pet
            case .pet: return .info
            case .info: return .normal
            }
        }
        var label: String {
            switch self {
            case .normal: return "NORMAL"
            case .pet: return "PET"
            case .info: return "INFO"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if showScanline { ScanlineOverlay() }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                petArea
                    .frame(maxWidth: .infinity)
                    .frame(height: petAreaHeight)

                Divider()
                    .background(TerminalStyle.lcdDivider)
                    .padding(.horizontal, 14)

                modeBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                    .gesture(horizontalSwipe)

                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsScreen(model: model, stats: stats)
        }
        .sheet(isPresented: $showLogs) {
            HomeLogSheet(model: model)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if autoStartBLE, model.bluetoothAuthorization == .allowedAlways {
                model.start(
                    displayName: effectiveDisplayName,
                    includeServiceUUIDInAdvertisement: true
                )
            }
        }
        .onReceive(promptTimer) { _ in
            if promptArrivedAt != nil { promptTick &+= 1 }
        }
        .onChange(of: model.prompt?.id) { _, newValue in
            if newValue != nil {
                promptArrivedAt = Date()
                promptTick = 0
            } else {
                promptArrivedAt = nil
            }
        }
    }

    // MARK: - Top bar (status indicator + gear)

    private var topBar: some View {
        HStack(spacing: 10) {
            statusIndicator
            Spacer(minLength: 0)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                    .frame(width: 32, height: 32)
                    .background(TerminalStyle.lcdPanel.opacity(0.7), in: Circle())
                    .overlay(
                        Circle().stroke(TerminalStyle.inkDim.opacity(0.45), lineWidth: 1)
                    )
            }
            .accessibilityLabel(Text("settings.title"))
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            BreathingLED(color: statusColor)
            Text(statusLabel)
                .font(TerminalStyle.mono(11, weight: .semibold))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TerminalStyle.lcdPanel.opacity(0.65), in: Capsule())
        .overlay(Capsule().stroke(TerminalStyle.inkDim.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Pet area (fixed size so body content never jitters)

    private var petArea: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
            buddyRenderer
                .padding(.horizontal, 24)
            VStack {
                HStack {
                    Text(mode.label)
                        .font(TerminalStyle.display(11, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(TerminalStyle.inkDim)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.5), in: Capsule())
                        .overlay(Capsule().stroke(TerminalStyle.inkDim.opacity(0.35), lineWidth: 1))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var buddyRenderer: some View {
        HomeBuddyRenderer(persona: persona, model: model)
    }

    // MARK: - Mode body

    @ViewBuilder
    private var modeBody: some View {
        switch mode {
        case .normal: NormalBody(
                model: model,
                persona: persona,
                promptWaitedSeconds: promptWaitedSeconds,
                promptTick: promptTick
            )
        case .pet: PetBody(
                stats: stats,
                page: petPage
            )
        case .info: InfoBody(
                model: model,
                persona: persona,
                page: infoPage,
                appStart: appStart,
                petName: petName,
                showScanline: showScanline
            )
        }
    }

    // MARK: - Bottom bar (handheld A / B / Log)

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HandheldButton(
                label: "A",
                accent: TerminalStyle.good,
                action: onPressA
            )
            HandheldButton(
                label: "B",
                accent: TerminalStyle.bad,
                action: onPressB
            )
            Spacer(minLength: 0)
            Button {
                showLogs = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 13, weight: .bold))
                    Text("home.log")
                        .font(TerminalStyle.mono(11, weight: .bold))
                        .tracking(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(TerminalStyle.ink)
                .background(TerminalStyle.lcdPanel.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TerminalStyle.inkDim.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Interactions

    private func onPressA() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if mode == .normal, model.prompt != nil {
            model.respondPermission(.once)
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            mode = mode.next
            if mode == .pet { petPage = 0 }
            if mode == .info { infoPage = 0 }
        }
    }

    private func onPressB() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        if mode == .normal, model.prompt != nil {
            model.respondPermission(.deny)
            return
        }
        switch mode {
        case .pet:
            withAnimation { petPage = (petPage + 1) % PetBody.pageCount }
        case .info:
            withAnimation { infoPage = (infoPage + 1) % InfoBody.pages.count }
        case .normal:
            break
        }
    }

    private var horizontalSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let step = value.translation.width < 0 ? 1 : -1
                switch mode {
                case .pet:
                    let count = PetBody.pageCount
                    withAnimation { petPage = (petPage + step + count) % count }
                case .info:
                    let count = InfoBody.pages.count
                    withAnimation { infoPage = (infoPage + step + count) % count }
                case .normal:
                    break
                }
            }
    }

    // MARK: - Derived UI state

    private var petAreaHeight: CGFloat { 220 }

    private var effectiveDisplayName: String? {
        let trimmed = persistedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var promptWaitedSeconds: Int {
        _ = promptTick
        guard let promptArrivedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(promptArrivedAt)))
    }

    // MARK: - Status computation
    //
    // Priority ladder (highest wins):
    //  1. BLE permission not granted (notDetermined / denied / restricted)
    //  2. Bluetooth off (poweredOff) or unsupported
    //  3. Claude Desktop connected
    //  4. Advertising but no central
    //  5. Idle / stopped
    // Deliberately ignores Claude-side turn state (busy / done) per spec.

    private var statusLabel: String {
        switch model.bluetoothAuthorization {
        case .notDetermined: return String(localized: "home.status.needsPermission")
        case .denied, .restricted: return String(localized: "home.status.permissionDenied")
        case .allowedAlways: break
        @unknown default: break
        }
        switch model.bluetoothPowerState {
        case .poweredOff: return String(localized: "home.status.bluetoothOff")
        case .unsupported: return String(localized: "home.status.unsupported")
        case .unauthorized: return String(localized: "home.status.permissionDenied")
        case .resetting, .unknown, .poweredOn: break
        @unknown default: break
        }
        switch model.connectionState {
        case .connected(let n):
            return n > 1
                ? String(format: String(localized: "home.status.connectedMany"), n)
                : String(localized: "home.status.connected")
        case .advertising:
            return String(localized: "home.status.advertising")
        case .stopped:
            return String(localized: "home.status.idle")
        }
    }

    private var statusColor: Color {
        switch model.bluetoothAuthorization {
        case .notDetermined: return TerminalStyle.accentSoft
        case .denied, .restricted: return TerminalStyle.bad
        case .allowedAlways: break
        @unknown default: break
        }
        switch model.bluetoothPowerState {
        case .poweredOff, .unsupported, .unauthorized: return TerminalStyle.bad
        case .resetting, .unknown, .poweredOn: break
        @unknown default: break
        }
        switch model.connectionState {
        case .connected: return TerminalStyle.good
        case .advertising: return TerminalStyle.accentSoft
        case .stopped: return TerminalStyle.inkDim
        }
    }
}

// MARK: - Pet renderer wrapper

private struct HomeBuddyRenderer: View {
    @ObservedObject var persona: PersonaController
    @ObservedObject var model: BridgeAppModel

    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()

    var body: some View {
        renderer
            .onAppear(perform: reload)
            .onChange(of: model.lastInstalledCharacter) { _, newValue in
                reload()
                if let newValue {
                    selection = .installed(name: newValue)
                    PersonaSelection.save(selection)
                }
            }
    }

    @ViewBuilder
    private var renderer: some View {
        switch resolved() {
        case .ascii:
            ASCIIBuddyView(state: persona.state)
                .scaleEffect(0.95)
        case .gif(let p):
            GIFView(persona: p, state: persona.state)
                .aspectRatio(contentMode: .fit)
        }
    }

    private enum Resolved {
        case ascii
        case gif(InstalledPersona)
    }

    private func resolved() -> Resolved {
        switch selection {
        case .asciiCat: return .ascii
        case .builtin(let n):
            if let m = builtin.first(where: { $0.name == n }) { return .gif(m) }
            return .ascii
        case .installed(let n):
            if let m = installed.first(where: { $0.name == n }) { return .gif(m) }
            return .ascii
        }
    }

    private func reload() {
        let catalog = PersonaCatalog(rootURL: model.charactersRootURL)
        installed = catalog.listInstalled()
        selection = PersonaSelection.load()
    }
}

// MARK: - Breathing LED

private struct BreathingLED: View {
    let color: Color
    @State private var glow = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(glow ? 0.85 : 0.25), radius: glow ? 6 : 2)
            .opacity(glow ? 1 : 0.55)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: glow)
            .onAppear { glow = true }
    }
}

// MARK: - Handheld button

private struct HandheldButton: View {
    let label: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.95), accent.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: Circle()
                )
                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 2))
                .shadow(color: accent.opacity(0.5), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(PressedScaleStyle())
    }
}

private struct PressedScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - NORMAL mode body

private struct NormalBody: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    let promptWaitedSeconds: Int
    let promptTick: Int

    @State private var spinPhase: Int = 0
    private let spinTimer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()
    private let spinGlyphs: [String] = ["·", "•", "·", "•"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let prompt = model.prompt {
                promptPanel(prompt)
            } else {
                statusLine
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parsedLog.indices, id: \.self) { idx in
                        parsedLogRow(parsedLog[idx])
                    }
                    if parsedLog.isEmpty {
                        Text("home.log.empty")
                            .font(TerminalStyle.mono(11))
                            .foregroundStyle(TerminalStyle.inkDim.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onReceive(spinTimer) { _ in
            spinPhase = (spinPhase + 1) % spinGlyphs.count
        }
    }

    private var statusLine: some View {
        let msg = model.snapshot.msg.isEmpty
            ? String(localized: "home.status.noClaude")
            : model.snapshot.msg
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(msg)
                    .font(TerminalStyle.mono(14, weight: .bold))
                    .foregroundStyle(TerminalStyle.ink)
                    .shadow(color: TerminalStyle.ink.opacity(0.35), radius: 3)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Text(spinGlyphs[spinPhase])
                    .font(TerminalStyle.mono(14, weight: .bold))
                    .foregroundStyle(TerminalStyle.accentSoft)
            }

            HStack(spacing: 12) {
                statusPill("sess", "\(model.snapshot.total)")
                statusPill("run", "\(model.snapshot.running)")
                statusPill("wait", "\(model.snapshot.waiting)")
                statusPill("tok/d", formatTokens(UInt32(max(0, model.snapshot.tokensToday))))
                Spacer(minLength: 0)
            }
        }
    }

    private func statusPill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(TerminalStyle.inkDim)
            Text(value)
                .foregroundStyle(TerminalStyle.ink)
        }
        .font(TerminalStyle.mono(10, weight: .semibold))
    }

    private func promptPanel(_ prompt: PromptRequest) -> some View {
        _ = promptTick
        let waited = promptWaitedSeconds
        let timerColor: Color = waited >= 10 ? TerminalStyle.accent : TerminalStyle.accentSoft
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(format: String(localized: "home.prompt.waited"), waited))
                .font(TerminalStyle.mono(11, weight: .semibold))
                .foregroundStyle(timerColor)
            Text(prompt.tool)
                .font(TerminalStyle.mono(18, weight: .bold))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            if !prompt.hint.isEmpty {
                Text(prompt.hint)
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            HStack(spacing: 14) {
                Label {
                    Text("home.prompt.approve")
                        .font(TerminalStyle.mono(11, weight: .bold))
                } icon: {
                    Text("A").font(TerminalStyle.mono(11, weight: .bold))
                }
                .foregroundStyle(TerminalStyle.good)
                Label {
                    Text("home.prompt.deny")
                        .font(TerminalStyle.mono(11, weight: .bold))
                } icon: {
                    Text("B").font(TerminalStyle.mono(11, weight: .bold))
                }
                .foregroundStyle(TerminalStyle.bad)
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TerminalStyle.lcdPanel.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TerminalStyle.accent.opacity(0.6), lineWidth: 1)
        )
    }

    // Spec 3.3: NORMAL shows only "解析后日志" (parsed log, time + msg).
    // Raw BLE wire events live in the BLE tab of the log sheet.
    private var parsedLog: [LogLine] {
        model.snapshot.entries.prefix(16).map(LogLine.init(parsed:))
    }

    private func parsedLogRow(_ line: LogLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(line.time)
                .font(TerminalStyle.mono(10))
                .foregroundStyle(TerminalStyle.inkDim)
                .frame(width: 44, alignment: .leading)
            Text(line.message)
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }

    private func formatTokens(_ v: UInt32) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", Double(v) / 1_000) }
        return "\(v)"
    }
}

private struct LogLine {
    let time: String
    let message: String

    init(parsed entry: String) {
        let parts = entry.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2, parts[0].contains(":") {
            self.time = String(parts[0])
            self.message = String(parts[1])
        } else {
            self.time = LogLine.currentClock()
            self.message = entry
        }
    }

    private static func currentClock() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}

// MARK: - PET mode body (h5-demo pet-view)

private struct PetBody: View {
    @ObservedObject var stats: PersonaStatsStore
    let page: Int

    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.ownerName") private var ownerName: String = ""

    static let pageCount = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayName)
                    .font(TerminalStyle.mono(12, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                    .tracking(1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text("\(page + 1)/\(Self.pageCount)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
            Divider().background(TerminalStyle.lcdDivider)
            if page == 0 { statsPage } else { howPage }
        }
    }

    private var displayName: String {
        let owner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = petName.isEmpty ? "Buddy" : petName
        return owner.isEmpty ? name : "\(owner)'s \(name)"
    }

    private var statsPage: some View {
        let s = stats.stats
        let mood = Int(s.moodTier)
        let fed = Int(s.fedProgress)
        let energy = Int(stats.energyTier())

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text("mood")
                    .frame(width: 56, alignment: .leading)
                    .foregroundStyle(TerminalStyle.inkDim)
                PetIndicator.MoodRow(tier: mood)
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                Text("fed")
                    .frame(width: 56, alignment: .leading)
                    .foregroundStyle(TerminalStyle.inkDim)
                PetIndicator.FedRow(filled: fed)
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                Text("energy")
                    .frame(width: 56, alignment: .leading)
                    .foregroundStyle(TerminalStyle.inkDim)
                PetIndicator.EnergyRow(tier: energy)
                Spacer(minLength: 0)
            }

            PetIndicator.LevelBadge(level: s.level)

            VStack(alignment: .leading, spacing: 2) {
                metric("approved", "\(s.approvals)")
                metric("denied", "\(s.denials)")
                metric("napped", formatNap(s.napSeconds))
                metric("tokens", formatTokens(s.tokens))
                metric("today", formatTokens(stats.tokensToday))
            }
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(12))
    }

    private var howPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            howLine("MOOD", "approve fast ↑ · deny lots ↓")
            howLine("FED", "50K tokens = Lv up")
            howLine("ENERGY", "face-down naps refill")
            howLine("TIP", "idle → sleep")
            howLine("TIP", "press A to cycle screens")
            howLine("TIP", "press B to flip pages")
            Spacer(minLength: 0)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 78, alignment: .leading)
                .foregroundStyle(TerminalStyle.inkDim)
            Text(value)
                .foregroundStyle(TerminalStyle.ink)
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(11))
    }

    private func howLine(_ tag: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tag)
                .font(TerminalStyle.mono(11, weight: .bold))
                .foregroundStyle(TerminalStyle.accent)
                .frame(width: 70, alignment: .leading)
            Text(text)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.ink)
            Spacer(minLength: 0)
        }
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
}

// MARK: - INFO mode body (h5-demo INFO_PAGES)

private struct InfoBody: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    let page: Int
    let appStart: Date
    let petName: String
    let showScanline: Bool

    static let pages: [String] = ["ABOUT", "BUTTONS", "CLAUDE", "DEVICE", "BLE", "CREDITS"]

    var body: some View {
        let title = Self.pages[page]
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Info")
                    .font(TerminalStyle.mono(11, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                    .tracking(1)
                Spacer()
                Text("\(page + 1)/\(Self.pages.count)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
            Text(title)
                .font(TerminalStyle.display(22))
                .tracking(3)
                .foregroundStyle(TerminalStyle.accent)
                .shadow(color: TerminalStyle.accentSoft.opacity(0.55), radius: 0, x: 2, y: 2)
            Divider().background(TerminalStyle.lcdDivider)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(lines(for: title), id: \.self) { line in
                    Text(line)
                        .font(TerminalStyle.mono(12))
                        .foregroundStyle(TerminalStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func lines(for page: String) -> [String] {
        switch page {
        case "ABOUT": return [
            "Claude Buddy Bridge",
            "iPhone ↔ Claude Desktop",
            "BLE NUS + pet simulator",
            "A: cycle screens · B: flip page"
        ]
        case "BUTTONS": return [
            "A: NORMAL → PET → INFO",
            "A (on prompt): approve",
            "B: page PET / INFO",
            "B (on prompt): deny",
            "Log: show raw packets"
        ]
        case "CLAUDE": return [
            "sessions: \(model.snapshot.total)",
            "running:  \(model.snapshot.running)",
            "waiting:  \(model.snapshot.waiting)",
            "state:    \(persona.state.slug)",
            "tok/d:    \(model.snapshot.tokensToday)"
        ]
        case "DEVICE":
            let uptime = Int(Date().timeIntervalSince(appStart))
            let device = UIDevice.current
            let raw = device.batteryLevel
            let batt = raw < 0 ? "—" : "\(Int((raw * 100).rounded()))%"
            let usb = (device.batteryState == .charging || device.batteryState == .full) ? "on" : "off"
            return [
                "battery: \(batt)",
                "usb:     \(usb)",
                "uptime:  \(formatUptime(uptime))",
                "scan:    \(showScanline ? "on" : "off")",
                "pet:     \(petName.isEmpty ? "Buddy" : petName)"
            ]
        case "BLE": return [
            "link:  \(shortConn)",
            "adv:   \(model.advertisingNote)",
            "name:  \(model.activeDisplayName)",
            "uuid:  6e400001-...e9d6"
        ]
        case "CREDITS": return [
            "idea: Felix Rieseberg",
            "anthropics/",
            "  claude-desktop-buddy",
            "iOS bridge: kingcos",
            "MIT-licensed"
        ]
        default: return []
        }
    }

    private var shortConn: String {
        switch model.connectionState {
        case .stopped: return "off"
        case .advertising: return "advertising"
        case .connected(let n): return "conn×\(n)"
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
}

// MARK: - Log bottom sheet

struct HomeLogSheet: View {
    @ObservedObject var model: BridgeAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: LogTab = .run

    enum LogTab: String, CaseIterable {
        case run, ble
        var label: LocalizedStringKey {
            switch self {
            case .run: return "home.logs.tab.run"
            case .ble: return "home.logs.tab.ble"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(LogTab.allCases, id: \.self) { t in
                    Button {
                        tab = t
                    } label: {
                        Text(t.label)
                            .font(TerminalStyle.mono(12, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(tab == t ? TerminalStyle.lcdBg : TerminalStyle.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                tab == t ? TerminalStyle.ink : TerminalStyle.lcdPanel.opacity(0.6),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(TerminalStyle.inkDim.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = currentLogText
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("home.logs.copy")
                    }
                    .font(TerminalStyle.mono(11, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(TerminalStyle.lcdPanel.opacity(0.6), in: Capsule())
                    .overlay(Capsule().stroke(TerminalStyle.inkDim.opacity(0.45), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(currentLog.indices, id: \.self) { i in
                        Text(currentLog[i])
                            .font(TerminalStyle.mono(11))
                            .foregroundStyle(TerminalStyle.ink.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    if currentLog.isEmpty {
                        Text("home.log.empty")
                            .font(TerminalStyle.mono(11))
                            .foregroundStyle(TerminalStyle.inkDim)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currentLog: [String] {
        switch tab {
        case .run:
            // Decoded Claude messages — "received info" in user's words.
            var lines: [String] = []
            if !model.snapshot.lastTurnPreview.isEmpty {
                lines.append("[turn:\(model.snapshot.lastTurnRole)] \(model.snapshot.lastTurnPreview)")
            }
            lines.append(contentsOf: model.snapshot.entries)
            return lines
        case .ble:
            // Raw wire events (protocol lines) + peripheral diagnostics —
            // the "old terminal page" log the user referenced.
            var lines: [String] = []
            lines.append(contentsOf: model.recentEvents.prefix(80))
            if !model.diagnosticLogs.isEmpty {
                lines.append("— diagnostics —")
                lines.append(contentsOf: model.diagnosticLogs)
            }
            return lines
        }
    }

    private var currentLogText: String {
        currentLog.joined(separator: "\n")
    }
}
