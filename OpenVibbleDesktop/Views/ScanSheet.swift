import SwiftUI
import NUSCentral

struct ScanSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Claude devices")
                    .font(.headline)
                Spacer()
                Button(scanButtonTitle) {
                    if case .scanning = state.connection {
                        state.stopScan()
                    } else {
                        state.startScan()
                    }
                }
            }

            if state.discovered.isEmpty {
                Text(emptyHint)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                List(state.discovered) { p in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(p.name).font(.body)
                            Text(p.id.uuidString).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(p.rssi) dBm").font(.caption).foregroundStyle(.secondary)
                        Button("Connect") {
                            state.connect(p)
                            dismiss()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 180)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear { state.startScan() }
        .onDisappear { state.stopScan() }
    }

    private var scanButtonTitle: String {
        if case .scanning = state.connection { return "Stop" }
        return "Scan"
    }

    private var emptyHint: String {
        switch state.connection {
        case .poweredOff: return state.bluetoothNote
        case .unauthorized: return "Bluetooth permission denied"
        case .unsupported: return "Bluetooth not supported on this Mac"
        case .scanning: return "Scanning… make sure the iOS app is open and broadcasting."
        default: return "No devices yet — tap Scan."
        }
    }
}
