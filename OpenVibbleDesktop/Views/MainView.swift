import SwiftUI
import NUSCentral
import BuddyProtocol

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @State private var showScanSheet = false
    @State private var nameDraft = "Claude-iOS"
    @State private var ownerDraft = "Felix"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            statusSection
            Divider()
            testPanel
            Divider()
            logSection
        }
        .padding(20)
        .sheet(isPresented: $showScanSheet) {
            ScanSheet().environmentObject(state)
        }
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(headerIndicator)
                .frame(width: 10, height: 10)
            Text(headerLabel)
                .font(.headline)
            Spacer()
            if isConnected {
                Button("Disconnect") { state.disconnect() }
            } else {
                Button("Connect") {
                    state.startScan()
                    showScanSheet = true
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if isConnected {
            VStack(alignment: .leading, spacing: 8) {
                row("Name", value: state.connectedName ?? "—")
                if let hb = state.heartbeat {
                    row("Sessions", value: "total \(hb.total) · running \(hb.running) · waiting \(hb.waiting)")
                    row("Tokens", value: "\(hb.tokens ?? 0) · today \(hb.tokensToday ?? 0)")
                    if let prompt = hb.prompt {
                        row("Pending", value: "\(prompt.tool ?? "?") — \(prompt.hint ?? "")")
                    } else {
                        row("Pending", value: "—")
                    }
                }
                if let ack = state.lastAck, let payload = ack.data, ack.ack == "status" {
                    statusAckView(payload)
                }
            }
        } else {
            Text("Not connected. Click Connect to scan for a Claude device.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusAckView(_ value: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let bat = value["bat"], let pct = bat["pct"]?.intValue {
                let usb = bat["usb"]?.boolValue == true
                row("Battery", value: "\(pct)% \(usb ? "· USB" : "")")
            }
            if let stats = value["stats"] {
                let lvl = stats["lvl"]?.intValue ?? 0
                let appr = stats["appr"]?.intValue ?? 0
                let vel = stats["vel"]?.intValue ?? 0
                row("Level", value: "\(lvl)")
                row("Approved", value: "\(appr)")
                row("Velocity", value: "\(vel)s")
            }
        }
    }

    private var testPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manual events")
                .font(.headline)
            HStack {
                Button("cmd:status") { state.sendStatus() }
                Button("cmd:unpair") { state.sendUnpair() }
                Button("time sync") { state.sendTimeSync() }
                Spacer()
            }
            HStack {
                TextField("name", text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("cmd:name") { state.sendName(nameDraft) }
                TextField("owner", text: $ownerDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("cmd:owner") { state.sendOwner(ownerDraft) }
            }
            HStack {
                Button("Approve pending") { state.approveCurrentPrompt() }
                    .disabled(state.heartbeat?.prompt == nil)
                Button("Deny pending") { state.denyCurrentPrompt() }
                    .disabled(state.heartbeat?.prompt == nil)
            }
        }
        .disabled(!isConnected)
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Activity")
                .font(.headline)
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
            .background(Color(white: 0.05))
            .cornerRadius(6)
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }

    private var isConnected: Bool {
        if case .connected = state.connection { return true }
        return false
    }

    private var headerLabel: String {
        switch state.connection {
        case .connected: return "Connected · Unencrypted"
        case .scanning: return "Scanning…"
        case .connecting: return "Connecting…"
        case .disconnecting: return "Disconnecting…"
        case .idle: return "Idle"
        case .poweredOff: return state.bluetoothNote
        case .unauthorized: return "Bluetooth permission denied"
        case .unsupported: return "Bluetooth not supported"
        case .unknown: return "Starting up…"
        case .error(let msg): return "Error: \(msg)"
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

private extension JSONValue {
    subscript(key: String) -> JSONValue? {
        if case let .object(dict) = self { return dict[key] }
        return nil
    }

    var intValue: Int? {
        if case let .number(v) = self { return Int(v) }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }
}
