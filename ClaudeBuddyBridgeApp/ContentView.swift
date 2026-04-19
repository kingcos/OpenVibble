import SwiftUI
import BuddyProtocol
import NUSPeripheral
import BridgeRuntime

struct ContentView: View {
    @StateObject private var model = BridgeAppModel()

    var body: some View {
        ZStack {
            terminalBackground
            scanlineOverlay

            VStack(alignment: .leading, spacing: 14) {
                topBar
                statusPanel
                logsPanel
                if let prompt = model.prompt {
                    promptPanel(prompt)
                }
                transferPanel
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var terminalBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.05), Color(red: 0.02, green: 0.03, blue: 0.03)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var scanlineOverlay: some View {
        GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                let width = proxy.size.width
                stride(from: 0, through: height, by: 3).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.green.opacity(0.05), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Label(connectionTitle, systemImage: connectionIcon)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(connectionColor)
            Spacer()
            Text("NUS 6e40…")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.75))
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("$ snapshot")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)

            Text(model.snapshot.msg)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.92))

            HStack(spacing: 12) {
                terminalMetric("total", value: "\(model.snapshot.total)")
                terminalMetric("running", value: "\(model.snapshot.running)")
                terminalMetric("waiting", value: "\(model.snapshot.waiting)")
                terminalMetric("today", value: "\(model.snapshot.tokensToday)")
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1))
    }

    private var logsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("$ tail -f buddy.log")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(combinedLogs.indices, id: \.self) { idx in
                        Text(combinedLogs[idx])
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(12)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1))
    }

    private func promptPanel(_ prompt: PromptRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("$ permission pending")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.yellow)

            Text("tool=\(prompt.tool) id=\(prompt.id)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.9))

            if !prompt.hint.isEmpty {
                Text(prompt.hint)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.85))
                    .lineLimit(2)
            }

            HStack {
                Button("approve once") {
                    model.respondPermission(.once)
                }
                .buttonStyle(TerminalActionButtonStyle(foreground: .black, background: .green))

                Button("deny") {
                    model.respondPermission(.deny)
                }
                .buttonStyle(TerminalActionButtonStyle(foreground: .white, background: .red.opacity(0.8)))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.45), lineWidth: 1))
    }

    private var transferPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("$ xfer")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)

            Text(model.transfer.isActive ? "\(model.transfer.characterName) :: \(model.transfer.currentFile)" : "idle")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.85))

            ProgressView(value: transferValue)
                .tint(.green)

            Text("\(model.transfer.writtenBytes) / \(model.transfer.totalBytes) bytes")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.75))
        }
        .padding(12)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1))
    }

    private func terminalMetric(_ key: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.7))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)
        }
    }

    private var combinedLogs: [String] {
        var lines = model.snapshot.entries.map { "LOG \($0)" }
        if !model.snapshot.lastTurnPreview.isEmpty {
            lines.insert("TURN [\(model.snapshot.lastTurnRole)] \(model.snapshot.lastTurnPreview)", at: 0)
        }
        lines.append(contentsOf: model.recentEvents.prefix(30))
        return Array(lines.prefix(60))
    }

    private var transferValue: Double {
        guard model.transfer.totalBytes > 0 else { return 0 }
        return Double(model.transfer.writtenBytes) / Double(model.transfer.totalBytes)
    }

    private var connectionTitle: String {
        switch model.connectionState {
        case .stopped:
            return "BLE stopped"
        case .advertising:
            return "BLE advertising"
        case .connected(let count):
            return "BLE connected x\(count)"
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
            return .red.opacity(0.9)
        case .advertising:
            return .yellow.opacity(0.9)
        case .connected:
            return .green
        }
    }
}

private struct TerminalActionButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background.opacity(configuration.isPressed ? 0.8 : 1.0), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.35), lineWidth: 1))
    }
}
