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
    @State private var frozenWaitedSeconds: Int?

    @AppStorage("bridge.displayName") private var persistedDisplayName = ""
    @AppStorage("bridge.autoStartBLE") private var autoStartBLE = true
    @AppStorage("buddy.petName") private var petName: String = "Buddy"

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
        var labelKey: LocalizedStringKey {
            switch self {
            case .normal: return "home.mode.normal"
            case .pet: return "home.mode.pet"
            case .info: return "home.mode.info"
            }
        }
    }

    var body: some View {
        ZStack {
            // Pure black — h5-demo uses #000 for .lcd-body, and the spec
            // calls out "黑色背景色" explicitly.
            Color.black.ignoresSafeArea()
            ScanlineOverlay()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    petArea
                        .frame(maxWidth: .infinity)
                        .frame(height: petAreaHeight(in: proxy.size.height))

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
            startBLEIfAllowed()
        }
        .onChange(of: model.bluetoothAuthorization) { _, _ in
            // Covers the case where the user grants BLE in Settings after
            // already skipping past onboarding — onAppear won't fire again
            // but this will, so advertising kicks in as soon as they return.
            startBLEIfAllowed()
        }
        .onReceive(promptTimer) { _ in
            if promptArrivedAt != nil { promptTick &+= 1 }
        }
        .onChange(of: model.prompt?.id) { _, newValue in
            if newValue != nil {
                promptArrivedAt = Date()
                promptTick = 0
                frozenWaitedSeconds = nil
            } else {
                promptArrivedAt = nil
                frozenWaitedSeconds = nil
            }
        }
        .onChange(of: model.responseSent) { _, sent in
            if sent, frozenWaitedSeconds == nil {
                frozenWaitedSeconds = promptWaitedSeconds
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
        let actionable = statusActionURL != nil
        let content = HStack(spacing: 8) {
            BreathingLED(color: statusColor)
            Text(statusLabel)
                .font(TerminalStyle.mono(11, weight: .semibold))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            if actionable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(TerminalStyle.lcdPanel.opacity(0.65), in: Capsule())
        .overlay(Capsule().stroke(
            (actionable ? statusColor.opacity(0.55) : TerminalStyle.inkDim.opacity(0.4)),
            lineWidth: 1
        ))

        return Group {
            if let url = statusActionURL {
                Button {
                    UIApplication.shared.open(url)
                } label: { content }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    /// Surface a tap target only when the user can actually do something about
    /// the current status (e.g. flip denied-permission in Settings). Passive
    /// states like "advertising" or "connected" have no action, so the pill
    /// stays non-interactive.
    private var statusActionURL: URL? {
        switch model.bluetoothAuthorization {
        case .denied, .restricted:
            return URL(string: UIApplication.openSettingsURLString)
        default: break
        }
        if model.bluetoothPowerState == .poweredOff {
            return URL(string: UIApplication.openSettingsURLString)
        }
        return nil
    }

    // MARK: - Pet area (fixed size so body content never jitters)

    private var petArea: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
            buddyRenderer
                .frame(maxWidth: 200, maxHeight: 200)
                .padding(.horizontal, 24)
            VStack {
                HStack {
                    Text(mode.labelKey)
                        .font(TerminalStyle.mono(10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(TerminalStyle.inkDim)
                    Spacer()
                    Text(personaStateKey(persona.state))
                        .font(TerminalStyle.mono(10, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(TerminalStyle.inkDim)
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
                petName: petName
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
            // Ignore repeat taps after the first response — the desktop
            // hasn't cleared the prompt yet, so another send would double
            // the approval.
            guard !model.responseSent else { return }
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
            guard !model.responseSent else { return }
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

    private func petAreaHeight(in availableHeight: CGFloat) -> CGFloat {
        // GIFs ship at ~160–200px native — beyond ~320pt on iPhone we start
        // upscaling and the pet looks blurry. Keep the area tight so the
        // image renders near 1:1 while still reserving the top of the LCD.
        let target = availableHeight * 0.36
        return min(320, max(220, target))
    }

    private func personaStateKey(_ state: PersonaState) -> LocalizedStringKey {
        switch state {
        case .sleep: return "state.sleep"
        case .idle: return "state.idle"
        case .busy: return "state.busy"
        case .attention: return "state.attention"
        case .celebrate: return "state.celebrate"
        case .dizzy: return "state.dizzy"
        case .heart: return "state.heart"
        }
    }

    private func startBLEIfAllowed() {
        guard autoStartBLE, model.bluetoothAuthorization == .allowedAlways else { return }
        model.start(
            displayName: effectiveDisplayName,
            includeServiceUUIDInAdvertisement: true
        )
    }

    private var effectiveDisplayName: String? {
        let trimmed = persistedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var promptWaitedSeconds: Int {
        _ = promptTick
        if let frozenWaitedSeconds { return frozenWaitedSeconds }
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
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                let current = PersonaSelection.load()
                if current != selection { selection = current }
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
            Group {
                if let prompt = model.prompt {
                    promptPanel(prompt)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                } else {
                    statusLine
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: model.prompt?.id)

            if parsedLog.isEmpty {
                VStack {
                    Spacer()
                    Text("home.log.empty")
                        .font(TerminalStyle.mono(11))
                        .foregroundStyle(TerminalStyle.inkDim.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(parsedLog.indices, id: \.self) { idx in
                            parsedLogRow(parsedLog[idx])
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
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
                statusPill("home.pill.sess", "\(model.snapshot.total)")
                statusPill("home.pill.run", "\(model.snapshot.running)")
                statusPill("home.pill.wait", "\(model.snapshot.waiting)")
                statusPill("home.pill.tokPerDay", formatTokens(UInt32(max(0, model.snapshot.tokensToday))))
                Spacer(minLength: 0)
            }
        }
    }

    private func statusPill(_ labelKey: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(labelKey)
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
                if model.responseSent {
                    Text("home.prompt.sent")
                        .font(TerminalStyle.mono(11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(TerminalStyle.good)
                } else {
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
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.18), value: model.responseSent)
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
                .frame(width: 58, alignment: .leading)
            Text(line.message)
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.string = "\(line.time) \(line.message)"
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("home.log.copy", systemImage: "doc.on.doc")
            }
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
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - PET mode body (h5-demo pet-view)

private struct PetBody: View {
    @ObservedObject var stats: PersonaStatsStore
    let page: Int

    static let pageCount = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("pet.title")
                    .font(TerminalStyle.display(20))
                    .tracking(2)
                    .foregroundStyle(TerminalStyle.ink)
                    .shadow(color: TerminalStyle.accent.opacity(0.4), radius: 0, x: 1, y: 1)
                Spacer()
                Text("\(page + 1)/\(Self.pageCount)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
            Divider().background(TerminalStyle.lcdDivider)
            if page == 0 { statsPage } else { howPage }
        }
    }

    private var statsPage: some View {
        let s = stats.stats
        let mood = Int(s.moodTier)
        let fed = Int(s.fedProgress)
        let energy = Int(stats.energyTier())

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text("pet.mood")
                    .frame(width: 56, alignment: .leading)
                    .foregroundStyle(TerminalStyle.inkDim)
                PetIndicator.MoodRow(tier: mood)
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                Text("pet.fed")
                    .frame(width: 56, alignment: .leading)
                    .foregroundStyle(TerminalStyle.inkDim)
                PetIndicator.FedRow(filled: fed)
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                Text("pet.energy")
                    .frame(width: 56, alignment: .leading)
                    .foregroundStyle(TerminalStyle.inkDim)
                PetIndicator.EnergyRow(tier: energy)
                Spacer(minLength: 0)
            }

            PetIndicator.LevelBadge(level: s.level)

            VStack(alignment: .leading, spacing: 2) {
                metric("pet.metric.approved", "\(s.approvals)")
                metric("pet.metric.denied", "\(s.denials)")
                metric("pet.metric.napped", formatNap(s.napSeconds))
                metric("pet.metric.tokens", formatTokens(s.tokens))
                metric("pet.metric.today", formatTokens(stats.tokensToday))
            }
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(12))
    }

    private var howPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            howLine("pet.how.tag.mood", "pet.how.mood")
            howLine("pet.how.tag.fed", "pet.how.fed")
            howLine("pet.how.tag.energy", "pet.how.energy")
            howLine("pet.how.tag.shake", "pet.how.shake")
            howLine("pet.how.tag.idle", "pet.how.idle")
            howLine("A", "pet.how.a")
            howLine("B", "pet.how.b")
            Spacer(minLength: 0)
        }
    }

    private func metric(_ labelKey: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(labelKey)
                .frame(width: 78, alignment: .leading)
                .foregroundStyle(TerminalStyle.inkDim)
            Text(value)
                .foregroundStyle(TerminalStyle.ink)
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(11))
    }

    private func howLine(_ tagKey: LocalizedStringKey, _ bodyKey: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tagKey)
                .font(TerminalStyle.mono(11, weight: .bold))
                .foregroundStyle(TerminalStyle.accent)
                .frame(width: 70, alignment: .leading)
            Text(bodyKey)
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

    static let pages: [String] = ["ABOUT", "BUTTONS", "CLAUDE", "DEVICE", "BLE", "CREDITS"]

    enum Row {
        case body(LocalizedStringKey)
        case pair(LocalizedStringKey, String)
    }

    var body: some View {
        let title = Self.pages[page]
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("info.title")
                    .font(TerminalStyle.display(20))
                    .tracking(2)
                    .foregroundStyle(TerminalStyle.ink)
                    .shadow(color: TerminalStyle.accent.opacity(0.4), radius: 0, x: 1, y: 1)
                Spacer()
                Text("\(page + 1)/\(Self.pages.count)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
            Text(titleKey(for: title))
                .font(TerminalStyle.display(15))
                .tracking(2)
                .foregroundStyle(TerminalStyle.accentSoft)
            Divider().background(TerminalStyle.lcdDivider)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(rows(for: title).enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row {
        case .body(let key):
            Text(key)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .pair(let labelKey, let value):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(labelKey)
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .frame(width: 82, alignment: .leading)
                Text(value)
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.ink)
                Spacer(minLength: 0)
            }
        }
    }

    private func rows(for page: String) -> [Row] {
        switch page {
        case "ABOUT": return [
            .body("info.about.line1"),
            .body("info.about.line2"),
            .body("info.about.line3"),
            .body("info.about.line4")
        ]
        case "BUTTONS": return [
            .body("info.buttons.line1"),
            .body("info.buttons.line2"),
            .body("info.buttons.line3"),
            .body("info.buttons.line4"),
            .body("info.buttons.line5")
        ]
        case "CLAUDE": return [
            .pair("info.claude.sessions", "\(model.snapshot.total)"),
            .pair("info.claude.running", "\(model.snapshot.running)"),
            .pair("info.claude.waiting", "\(model.snapshot.waiting)"),
            .pair("info.claude.state", localizedPersonaState(persona.state)),
            .pair("info.claude.tokPerDay", "\(model.snapshot.tokensToday)")
        ]
        case "DEVICE":
            let uptime = Int(Date().timeIntervalSince(appStart))
            let device = UIDevice.current
            let raw = device.batteryLevel
            let batt = raw < 0 ? "—" : "\(Int((raw * 100).rounded()))%"
            let usb = (device.batteryState == .charging || device.batteryState == .full)
                ? String(localized: "info.device.on")
                : String(localized: "info.device.off")
            return [
                .pair("info.device.battery", batt),
                .pair("info.device.usb", usb),
                .pair("info.device.uptime", formatUptime(uptime)),
                .pair("info.device.pet", petName.isEmpty ? "Buddy" : petName)
            ]
        case "BLE": return [
            .pair("info.ble.link", shortConn),
            .pair("info.ble.adv", model.advertisingNote),
            .pair("info.ble.name", model.activeDisplayName),
            .pair("info.ble.uuid", "6e400001-...e9d6")
        ]
        case "CREDITS": return [
            .body("info.credits.line1"),
            .body("info.credits.line2"),
            .body("info.credits.line4")
        ]
        default: return []
        }
    }

    private func localizedPersonaState(_ state: PersonaState) -> String {
        switch state {
        case .sleep: return String(localized: "state.sleep")
        case .idle: return String(localized: "state.idle")
        case .busy: return String(localized: "state.busy")
        case .attention: return String(localized: "state.attention")
        case .celebrate: return String(localized: "state.celebrate")
        case .dizzy: return String(localized: "state.dizzy")
        case .heart: return String(localized: "state.heart")
        }
    }

    private func titleKey(for page: String) -> LocalizedStringKey {
        switch page {
        case "ABOUT": return "info.page.about.title"
        case "BUTTONS": return "info.page.buttons.title"
        case "CLAUDE": return "info.page.claude.title"
        case "DEVICE": return "info.page.device.title"
        case "BLE": return "info.page.ble.title"
        case "CREDITS": return "info.page.credits.title"
        default: return LocalizedStringKey(page)
        }
    }

    private var shortConn: String {
        switch model.connectionState {
        case .stopped: return String(localized: "info.ble.link.off")
        case .advertising: return String(localized: "info.ble.link.advertising")
        case .connected(let n): return String(format: String(localized: "info.ble.link.conn"), n)
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
    @State private var copied: Bool = false
    @State private var copyResetTask: Task<Void, Never>?

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
                        HStack(spacing: 5) {
                            Text(t.label)
                                .font(TerminalStyle.mono(12, weight: .bold))
                                .tracking(1)
                            Text("\(lines(for: t).count)")
                                .font(TerminalStyle.mono(10, weight: .semibold))
                                .foregroundStyle(tab == t ? TerminalStyle.lcdBg.opacity(0.6) : TerminalStyle.inkDim)
                        }
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
                Button(action: copyCurrentLog) {
                    iconButton(icon: copied ? "checkmark" : "doc.on.doc",
                               tint: copied ? TerminalStyle.good : TerminalStyle.ink)
                }
                Button(action: clearCurrentLog) {
                    iconButton(icon: "trash", tint: TerminalStyle.bad)
                }
                .disabled(currentLog.isEmpty)
                .opacity(currentLog.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if currentLog.isEmpty {
                VStack {
                    Spacer()
                    Text("home.log.empty")
                        .font(TerminalStyle.mono(11))
                        .foregroundStyle(TerminalStyle.inkDim)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(currentLog.indices, id: \.self) { i in
                            Text(currentLog[i])
                                .font(TerminalStyle.mono(11))
                                .foregroundStyle(TerminalStyle.ink.opacity(0.92))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = currentLog[i]
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Label("home.log.copy", systemImage: "doc.on.doc")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func iconButton(icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(TerminalStyle.mono(11, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 26)
            .background(TerminalStyle.lcdPanel.opacity(0.6), in: Capsule())
            .overlay(Capsule().stroke(TerminalStyle.inkDim.opacity(0.45), lineWidth: 1))
    }

    private func clearCurrentLog() {
        switch tab {
        case .run, .ble:
            model.clearLogs()
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private var currentLog: [String] { lines(for: tab) }

    private func lines(for tab: LogTab) -> [String] {
        switch tab {
        case .run:
            var out: [String] = []
            if !model.snapshot.lastTurnPreview.isEmpty {
                out.append("[turn:\(model.snapshot.lastTurnRole)] \(model.snapshot.lastTurnPreview)")
            }
            out.append(contentsOf: model.snapshot.entries)
            return out
        case .ble:
            var out: [String] = []
            out.append(contentsOf: model.recentEvents.prefix(80))
            if !model.diagnosticLogs.isEmpty {
                out.append("— diagnostics —")
                out.append(contentsOf: model.diagnosticLogs)
            }
            return out
        }
    }

    private func copyCurrentLog() {
        let text = currentLog.joined(separator: "\n")
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        copied = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copied = false }
        }
    }
}
