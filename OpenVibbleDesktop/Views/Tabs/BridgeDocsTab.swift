import SwiftUI
import AppKit
import HookBridge

struct BridgeDocsTab: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LText("desktop.bridge.intro")
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox(label: LText("desktop.bridge.baseUrl")) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let port = state.bridgePort {
                            labeled("http://127.0.0.1:\(port)")
                        } else {
                            LText("desktop.bridge.notReady").foregroundStyle(.secondary)
                        }
                        HStack {
                            LText("desktop.bridge.portFile")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("~/.claude/openvibble.port")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GroupBox(label: LText("desktop.bridge.endpoints")) {
                    VStack(alignment: .leading, spacing: 6) {
                        endpointRow(method: "POST", path: "/pretooluse",    note: "blocking (≤30s)")
                        endpointRow(method: "POST", path: "/prompt",        note: "fire-and-forget")
                        endpointRow(method: "POST", path: "/stop",          note: "fire-and-forget")
                        endpointRow(method: "POST", path: "/notification",  note: "fire-and-forget")
                        endpointRow(method: "GET",  path: "/health",        note: "unauthenticated")
                    }
                }

                GroupBox(label: LText("desktop.bridge.exampleCurl")) {
                    exampleCurl
                }

                Button(action: openRepo) {
                    Label("GitHub", systemImage: "arrow.up.right.square")
                }
            }
            .padding(16)
        }
    }

    private var exampleCurl: some View {
        let cmd = """
        curl -s --max-time 30 \\
          -H "X-OVD-Token: $(jq -r .token ~/.claude/openvibble.port)" \\
          http://127.0.0.1:$(jq -r .port ~/.claude/openvibble.port)/pretooluse \\
          -d '{"session_id":"demo","cwd":"/path/to/project","tool_name":"Bash","tool_input":{"command":"ls"}}'
        """
        return HStack(alignment: .top) {
            Text(cmd)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            Button(action: { copyToPasteboard(cmd) }) { LText("desktop.bridge.copy") }
                .buttonStyle(.borderless)
        }
    }

    private func endpointRow(method: String, path: String, note: String) -> some View {
        HStack {
            Text(method).font(.caption.bold()).frame(width: 50, alignment: .leading)
            Text(path).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Text(note).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func labeled(_ s: String) -> some View {
        HStack {
            Text(s).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
            Button(action: { copyToPasteboard(s) }) { LText("desktop.bridge.copy") }
                .buttonStyle(.borderless)
        }
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func openRepo() {
        if let url = URL(string: "https://github.com/kingcos/claude-buddy-bridge-ios") {
            NSWorkspace.shared.open(url)
        }
    }
}
