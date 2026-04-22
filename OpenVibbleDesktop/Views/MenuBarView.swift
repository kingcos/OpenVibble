import SwiftUI
import NUSCentral

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    let openMainWindow: () -> Void

    var body: some View {
        Group {
            Text(summaryLine)
                .font(.caption)
            Divider()

            switch state.connection {
            case .connected:
                Button("Disconnect") { state.disconnect() }
            case .scanning:
                Button("Stop scanning") { state.stopScan() }
            default:
                Button("Start scanning") { state.startScan() }
            }

            Button("Open window") { openMainWindow() }
            Divider()
            Button("Quit OpenVibbleDesktop") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    private var summaryLine: String {
        switch state.connection {
        case .connected:
            return "Connected · \(state.connectedName ?? "Claude")"
        case .scanning:
            return "Scanning for Claude…"
        case .connecting:
            return "Connecting…"
        case .poweredOff:
            return "Bluetooth is off"
        case .unauthorized:
            return "Bluetooth permission denied"
        case .unsupported:
            return "Bluetooth not supported"
        case .error(let msg):
            return "Error: \(msg)"
        default:
            return "Idle"
        }
    }
}
