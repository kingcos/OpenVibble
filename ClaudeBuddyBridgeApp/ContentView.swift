import SwiftUI
import BuddyProtocol
import NUSPeripheral
import BridgeRuntime

struct ContentView: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController

    @AppStorage("bridge.displayName") private var persistedDisplayName = ""
    @AppStorage("buddy.showScanline") private var showScanline = true
    @AppStorage("bridge.autoStartBLE") private var autoStartBLE = true

    var body: some View {
        ZStack {
            TerminalBackground(showScanline: showScanline)

            VStack(alignment: .leading, spacing: 12) {
                topBar
                actionBar
                statusPanel
                logsPanel
                if let prompt = model.prompt {
                    promptPanel(prompt)
                }
                if model.transfer.isActive {
                    transferPanel
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if autoStartBLE {
                model.start(
                    displayName: effectiveDisplayName,
                    includeServiceUUIDInAdvertisement: true
                )
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Label(connectionTitle, systemImage: connectionIcon)
                .font(TerminalStyle.mono(13, weight: .semibold))
                .foregroundStyle(connectionColor)
            Spacer(minLength: 8)
            Text("pet:\(persona.state.slug)")
                .font(TerminalStyle.mono(10, weight: .semibold))
                .foregroundStyle(TerminalStyle.inkDim)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(TerminalStyle.inkDim.opacity(0.55), lineWidth: 1)
                )
            Text("NUS 6e40…")
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.inkDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionBar: some View {
        Button("$ ble --restart") {
            model.restart(
                displayName: effectiveDisplayName,
                includeServiceUUIDInAdvertisement: true
            )
        }
        .buttonStyle(TerminalHeaderButtonStyle(fill: true))
    }

    private var statusPanel: some View {
        TerminalPanel("ps aux") {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.snapshot.msg)
                    .font(TerminalStyle.mono(14))
                    .foregroundStyle(TerminalStyle.ink)

                HStack(spacing: 12) {
                    terminalMetric("sess",  value: "\(model.snapshot.total)")
                    terminalMetric("run",   value: "\(model.snapshot.running)")
                    terminalMetric("wait",  value: "\(model.snapshot.waiting)")
                    terminalMetric("tokd",  value: "\(model.snapshot.tokensToday)")
                }

                Text("[ble]  \(model.bluetoothStateNote)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)

                Text("[adv]  \(model.advertisingNote)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)

                Text("[name] \(model.activeDisplayName)")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
        }
    }

    private var logsPanel: some View {
        TerminalPanel("tail -f buddy.log") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(combinedLogs.indices, id: \.self) { idx in
                        Text(combinedLogs[idx])
                            .font(TerminalStyle.mono(12))
                            .foregroundStyle(TerminalStyle.ink.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func promptPanel(_ prompt: PromptRequest) -> some View {
        TerminalPanel("sudo?", accent: TerminalStyle.accent) {
            VStack(alignment: .leading, spacing: 10) {
                Text("⚠ \(prompt.tool) 待确认")
                    .font(TerminalStyle.mono(12, weight: .semibold))
                    .foregroundStyle(TerminalStyle.accent)

                if !prompt.hint.isEmpty {
                    Text(prompt.hint)
                        .font(TerminalStyle.mono(12))
                        .foregroundStyle(TerminalStyle.accentSoft)
                        .lineLimit(2)
                }

                HStack {
                    Button("允许") { model.respondPermission(.once) }
                        .buttonStyle(TerminalActionButtonStyle(
                            foreground: .white,
                            background: TerminalStyle.good
                        ))

                    Button("拒绝") { model.respondPermission(.deny) }
                        .buttonStyle(TerminalActionButtonStyle(
                            foreground: .white,
                            background: TerminalStyle.bad
                        ))
                }
            }
        }
    }

    private var transferPanel: some View {
        TerminalPanel("scp \(model.transfer.currentFile)") {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(model.transfer.characterName) :: \(model.transfer.currentFile)")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.ink)

                ProgressView(value: transferValue)
                    .tint(TerminalStyle.ink)

                Text("\(model.transfer.writtenBytes) / \(model.transfer.totalBytes) B")
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
        }
    }

    private func terminalMetric(_ key: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.inkDim)
            Text(value)
                .font(TerminalStyle.mono(11, weight: .semibold))
                .foregroundStyle(TerminalStyle.ink)
        }
    }

    private var combinedLogs: [String] {
        var lines = model.snapshot.entries.map { "[log]  \($0)" }
        if !model.snapshot.lastTurnPreview.isEmpty {
            lines.insert("[turn:\(model.snapshot.lastTurnRole)] \(model.snapshot.lastTurnPreview)", at: 0)
        }
        lines.append(contentsOf: model.recentEvents.prefix(30).map { "[evt]  \($0)" })
        lines.append(contentsOf: model.diagnosticLogs.prefix(20).map { "[ble]  \($0)" })
        return Array(lines.prefix(80))
    }

    private var transferValue: Double {
        guard model.transfer.totalBytes > 0 else { return 0 }
        return Double(model.transfer.writtenBytes) / Double(model.transfer.totalBytes)
    }

    private var connectionTitle: String {
        switch model.connectionState {
        case .stopped:
            return "ble: down"
        case .advertising:
            return "ble: advertising"
        case .connected(let count):
            return "ble: conn×\(count)"
        }
    }

    private var connectionIcon: String {
        switch model.connectionState {
        case .stopped:
            return "bolt.slash"
        case .advertising:
            return "dot.radiowaves.left.and.right"
        case .connected:
            return "bolt.horizontal.circle.fill"
        }
    }

    private var connectionColor: Color {
        switch model.connectionState {
        case .stopped:
            return TerminalStyle.bad
        case .advertising:
            return TerminalStyle.accentSoft
        case .connected:
            return TerminalStyle.ink
        }
    }

    private var effectiveDisplayName: String? {
        let trimmed = persistedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}
