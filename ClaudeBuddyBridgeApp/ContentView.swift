import SwiftUI
import BuddyProtocol
import NUSPeripheral
import BridgeRuntime

struct ContentView: View {
    @StateObject private var model = BridgeAppModel()
    @State private var showHelpSheet = false
    @State private var showSettingsSheet = false
    @State private var draftDisplayName = ""

    @AppStorage("bridge.displayName") private var persistedDisplayName = ""
    @AppStorage("bridge.showScanline") private var showScanline = true
    @AppStorage("bridge.autoStartBLE") private var autoStartBLE = true

    var body: some View {
        ZStack {
            terminalBackground
            if showScanline {
                scanlineOverlay
            }

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showHelpSheet) {
            helpSheet
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheet
        }
        .onAppear {
            draftDisplayName = persistedDisplayName
            if autoStartBLE {
                model.start(displayName: effectiveDisplayName)
            }
        }
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
            Button("帮助") { showHelpSheet = true }
                .buttonStyle(TerminalHeaderButtonStyle())
            Button("设置") { showSettingsSheet = true }
                .buttonStyle(TerminalHeaderButtonStyle())
            Text("NUS 6e40…")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.75))
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("$ 状态快照")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)

            Text(model.snapshot.msg)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.92))

            HStack(spacing: 12) {
                terminalMetric("总会话", value: "\(model.snapshot.total)")
                terminalMetric("运行中", value: "\(model.snapshot.running)")
                terminalMetric("待确认", value: "\(model.snapshot.waiting)")
                terminalMetric("今日", value: "\(model.snapshot.tokensToday)")
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
            Text("$ 权限待确认")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.yellow)

            Text("工具=\(prompt.tool) id=\(prompt.id)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.9))

            if !prompt.hint.isEmpty {
                Text(prompt.hint)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.85))
                    .lineLimit(2)
            }

            HStack {
                Button("本次允许") {
                    model.respondPermission(.once)
                }
                .buttonStyle(TerminalActionButtonStyle(foreground: .black, background: .green))

                Button("拒绝") {
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
            Text("$ 文件传输")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)

            Text(model.transfer.isActive ? "\(model.transfer.characterName) :: \(model.transfer.currentFile)" : "空闲")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.green.opacity(0.85))

            ProgressView(value: transferValue)
                .tint(.green)

            Text("\(model.transfer.writtenBytes) / \(model.transfer.totalBytes) 字节")
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
        var lines = model.snapshot.entries.map { "日志 \($0)" }
        if !model.snapshot.lastTurnPreview.isEmpty {
            lines.insert("回合 [\(model.snapshot.lastTurnRole)] \(model.snapshot.lastTurnPreview)", at: 0)
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
            return "BLE 未启动"
        case .advertising:
            return "BLE 广播中"
        case .connected(let count):
            return "BLE 已连接 x\(count)"
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

    private var effectiveDisplayName: String? {
        let trimmed = persistedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var helpSheet: some View {
        ZStack {
            terminalBackground
            if showScanline {
                scanlineOverlay
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("$ 帮助")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)

                helpBlock(title: "连接 Claude Desktop", lines: [
                    "1. 在 Claude Desktop 打开开发者模式",
                    "2. 打开 Developer -> Hardware Buddy",
                    "3. 选择以 Claude- 开头的本机设备名完成连接"
                ])

                helpBlock(title: "权限确认", lines: [
                    "收到 prompt 后可在本页直接点击「本次允许 / 拒绝」",
                    "响应会通过 BLE 回传给 Claude Desktop"
                ])

                helpBlock(title: "文件推送", lines: [
                    "支持 char_begin / file / chunk / file_end / char_end",
                    "传输进度可在主页面底部实时查看"
                ])

                Spacer()

                Button("关闭") { showHelpSheet = false }
                    .buttonStyle(TerminalActionButtonStyle(foreground: .black, background: .green))
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func helpBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("$ \(title)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.green)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.9))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.35), lineWidth: 1))
    }

    private var settingsSheet: some View {
        ZStack {
            terminalBackground
            if showScanline {
                scanlineOverlay
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("$ 设置")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 8) {
                    Text("设备显示名（可选）")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.85))
                    TextField("例如 Claude-iPhone", text: $draftDisplayName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(10)
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.35), lineWidth: 1))
                }

                Toggle("自动启动 BLE", isOn: $autoStartBLE)
                    .font(.system(size: 13, design: .monospaced))
                    .tint(.green)
                    .foregroundStyle(.green.opacity(0.95))

                Toggle("显示扫描线效果", isOn: $showScanline)
                    .font(.system(size: 13, design: .monospaced))
                    .tint(.green)
                    .foregroundStyle(.green.opacity(0.95))

                HStack {
                    Button("保存并应用") {
                        persistedDisplayName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if autoStartBLE {
                            model.restart(displayName: effectiveDisplayName)
                        } else {
                            model.stop()
                        }
                        showSettingsSheet = false
                    }
                    .buttonStyle(TerminalActionButtonStyle(foreground: .black, background: .green))

                    Button("取消") { showSettingsSheet = false }
                        .buttonStyle(TerminalActionButtonStyle(foreground: .white, background: .gray.opacity(0.45)))
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

private struct TerminalHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(configuration.isPressed ? 0.6 : 0.45), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.35), lineWidth: 1))
    }
}
