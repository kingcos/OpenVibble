import SwiftUI
import AppKit
import BuddyProtocol
import BuddyPersona

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var showScanSheet = false
    @State private var nameDraft = "Claude-iOS"
    @State private var ownerDraft = "Felix"
    @State private var packNameDraft = ""
    @State private var speciesSelection: Int = 4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                deviceSection
                batterySection
                statsSection
                systemSection
                pendingSection
                manualSection
                speciesSection
                installSection
                logSection
            }
            .padding(16)
        }
        .environment(\.localizationBundle, l10n.bundle)
        .sheet(isPresented: $showScanSheet) {
            ScanSheet().environmentObject(state).environment(\.localizationBundle, l10n.bundle)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(headerIndicator)
                .frame(width: 10, height: 10)
            Text(headerLabel).font(.headline)
            Spacer()
            languagePicker
            Button(action: { openWindow(id: "about") }) {
                Label {
                    LText("desktop.about")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
            if isConnected {
                Button(action: { state.disconnect() }) { LText("desktop.btn.disconnect") }
            } else {
                Button(action: {
                    state.startScan()
                    showScanSheet = true
                }) { LText("desktop.btn.connect") }
            }
        }
    }

    private var languagePicker: some View {
        Menu {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    l10n.set(lang)
                } label: {
                    HStack {
                        Text(lang.titleKey, bundle: l10n.bundle)
                        if l10n.language == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(l10n.language.titleKey, bundle: l10n.bundle)
            } icon: {
                Image(systemName: "globe")
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: Sections

    private var deviceSection: some View {
        GroupBox(label: LText("desktop.device")) {
            if isConnected {
                VStack(alignment: .leading, spacing: 6) {
                    infoRow(key: "desktop.device.name", value: state.connectedName ?? "—")
                    infoRow(key: "desktop.device.security", value: l10n.bundle.l("desktop.device.unencrypted"))
                }
            } else {
                LText("desktop.device.none")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var batterySection: some View {
        GroupBox(label: LText("desktop.battery")) {
            VStack(alignment: .leading, spacing: 6) {
                let snap = state.statusSnapshot
                infoRow(key: "desktop.battery.pct", value: snap.batteryPct.map { "\($0)%" } ?? "—")
                infoRow(key: "desktop.battery.usb", value: snap.batteryUsb.map { $0 ? "✓" : "—" } ?? "—")
                infoRow(key: "desktop.battery.voltage", value: snap.batteryVoltageMv.map { "\($0) mV" } ?? "—")
            }
        }
    }

    private var statsSection: some View {
        GroupBox(label: LText("desktop.stats")) {
            VStack(alignment: .leading, spacing: 6) {
                let snap = state.statusSnapshot
                infoRow(key: "desktop.stats.level", value: snap.statsLevel.map { "\($0)" } ?? "—")
                infoRow(key: "desktop.stats.approved", value: snap.statsApproved.map { "\($0)" } ?? "—")
                if let v = snap.statsVelocitySec {
                    infoRow(key: "desktop.stats.velocity", value: l10n.bundle.l("desktop.stats.velocity.sec", v))
                } else {
                    infoRow(key: "desktop.stats.velocity", value: "—")
                }
            }
        }
    }

    private var systemSection: some View {
        GroupBox(label: LText("desktop.system")) {
            VStack(alignment: .leading, spacing: 6) {
                let snap = state.statusSnapshot
                infoRow(key: "desktop.system.fw", value: snap.sysFirmware ?? "—")
                infoRow(key: "desktop.system.uptime", value: snap.sysUptimeSec.map { formatUptime($0) } ?? "—")
                if let rx = snap.xferRx, let tx = snap.xferTx {
                    infoRow(key: "desktop.system.xfer", value: l10n.bundle.l("desktop.xfer.stats", rx, tx))
                } else {
                    infoRow(key: "desktop.system.xfer", value: "—")
                }
                if let hb = state.heartbeat {
                    infoRow(key: "desktop.session",
                            value: l10n.bundle.l("desktop.session.counts", hb.total, hb.running, hb.waiting))
                    infoRow(key: "desktop.session.tokens",
                            value: l10n.bundle.l("desktop.session.tokensFmt", hb.tokens ?? 0, hb.tokensToday ?? 0))
                }
            }
        }
    }

    private var pendingSection: some View {
        GroupBox(label: LText("desktop.pending")) {
            if let prompt = state.heartbeat?.prompt {
                VStack(alignment: .leading, spacing: 6) {
                    infoRow(key: "desktop.pending.id", value: prompt.id)
                    infoRow(key: "desktop.pending.tool", value: prompt.tool ?? "—")
                    infoRow(key: "desktop.pending.hint", value: prompt.hint ?? "—")
                    HStack {
                        Button(action: { state.approveCurrentPrompt() }) { LText("desktop.btn.approve") }
                            .tint(.green)
                        Button(action: { state.denyCurrentPrompt() }) { LText("desktop.btn.deny") }
                            .tint(.red)
                    }
                }
            } else {
                LText("desktop.pending.none").foregroundStyle(.secondary)
            }
        }
    }

    private var manualSection: some View {
        GroupBox(label: LText("desktop.manual")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(action: { state.sendStatus() }) { LText("desktop.cmd.status") }
                    Button(action: { state.sendTimeSync() }) { LText("desktop.cmd.time") }
                    Button(action: { state.sendUnpair() }) { LText("desktop.cmd.unpair") }
                    Spacer()
                }
                HStack {
                    TextField(l10n.bundle.l("desktop.placeholder.name"), text: $nameDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    Button(action: { state.sendName(nameDraft) }) { LText("desktop.cmd.name") }
                    TextField(l10n.bundle.l("desktop.placeholder.owner"), text: $ownerDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    Button(action: { state.sendOwner(ownerDraft) }) { LText("desktop.cmd.owner") }
                }
            }
        }
        .disabled(!isConnected)
    }

    private var speciesSection: some View {
        GroupBox(label: LText("desktop.species")) {
            HStack {
                Picker(selection: $speciesSelection) {
                    ForEach(Array(PersonaSpeciesCatalog.names.enumerated()), id: \.offset) { idx, name in
                        Text(name).tag(idx)
                    }
                    Divider()
                    Text(l10n.bundle.l("desktop.species.gif")).tag(PersonaSpeciesCatalog.gifSentinel)
                } label: {
                    EmptyView()
                }
                .frame(maxWidth: 260)
                Button(action: { state.sendSpecies(index: speciesSelection) }) { LText("desktop.btn.send") }
            }
        }
        .disabled(!isConnected)
    }

    private var installSection: some View {
        GroupBox(label: LText("desktop.install")) {
            VStack(alignment: .leading, spacing: 8) {
                LText("desktop.install.hint")
                    .foregroundStyle(.secondary)
                HStack {
                    TextField(l10n.bundle.l("desktop.placeholder.pack"), text: $packNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    Button(action: pickFolder) { LText("desktop.install.pick") }
                    if state.installRunning {
                        Button(action: { state.cancelInstall() }) { LText("desktop.install.cancel") }
                            .tint(.red)
                    }
                }
                if let p = state.installProgress {
                    ProgressView(value: Double(p.writtenBytes), total: Double(max(1, p.totalBytes))) {
                        Text(l10n.bundle.l("desktop.install.progress", p.characterName, p.fileIndex, p.fileCount, p.writtenBytes))
                            .font(.caption)
                    }
                }
                if let err = state.installError, !state.installRunning {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .disabled(!isConnected && state.installProgress == nil)
    }

    private var logSection: some View {
        GroupBox(label:
            HStack {
                LText("desktop.activity")
                Spacer()
                Button(action: { state.clearLog() }) { LText("desktop.activity.clear") }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(state.activityLog.indices, id: \.self) { index in
                        Text(state.activityLog[index])
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)
        }
    }

    // MARK: Helpers

    private func infoRow(key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            LText(key)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            state.installCharacter(from: url, name: packNameDraft)
        }
    }

    private func formatUptime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    private var isConnected: Bool {
        if case .connected = state.connection { return true }
        return false
    }

    private var headerLabel: String {
        switch state.connection {
        case .connected:
            let name = state.connectedName ?? l10n.bundle.l("desktop.value.none")
            return l10n.bundle.l("desktop.menu.summary.connected", name)
        case .scanning: return l10n.bundle.l("desktop.header.scanning")
        case .connecting: return l10n.bundle.l("desktop.header.connecting")
        case .disconnecting: return l10n.bundle.l("desktop.header.disconnecting")
        case .idle: return l10n.bundle.l("desktop.header.idle")
        case .poweredOff: return state.bluetoothNote
        case .unauthorized: return l10n.bundle.l("desktop.header.unauth")
        case .unsupported: return l10n.bundle.l("desktop.header.unsupported")
        case .unknown: return l10n.bundle.l("desktop.header.startup")
        case .error(let msg): return l10n.bundle.l("desktop.header.error", msg)
        }
    }

    private var headerIndicator: Color {
        switch state.connection {
        case .connected: return .blue
        case .scanning, .connecting: return .orange
        case .error, .poweredOff, .unauthorized, .unsupported: return .red
        default: return .gray
        }
    }
}
