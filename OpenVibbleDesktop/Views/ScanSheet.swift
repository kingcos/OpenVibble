import SwiftUI
import NUSCentral

struct ScanSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                LText("desktop.scan.title").font(.headline)
                Spacer()
                Button(action: toggleScan) {
                    Text(scanButtonKey, bundle: l10n.bundle)
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
                        Button(action: {
                            state.connect(p)
                            dismiss()
                        }) { LText("desktop.btn.connect") }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 180)
            }

            HStack {
                Spacer()
                Button(action: { dismiss() }) { LText("desktop.btn.close") }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear { state.startScan() }
        .onDisappear { state.stopScan() }
        .environment(\.localizationBundle, l10n.bundle)
    }

    private func toggleScan() {
        if case .scanning = state.connection {
            state.stopScan()
        } else {
            state.startScan()
        }
    }

    private var scanButtonKey: LocalizedStringKey {
        if case .scanning = state.connection { return "desktop.btn.stop" }
        return "desktop.btn.scan"
    }

    private var emptyHint: String {
        switch state.connection {
        case .poweredOff: return state.bluetoothNote
        case .unauthorized: return l10n.bundle.l("desktop.scan.empty.unauth")
        case .unsupported: return l10n.bundle.l("desktop.scan.empty.unsupported")
        case .scanning: return l10n.bundle.l("desktop.scan.empty.scanning")
        default: return l10n.bundle.l("desktop.scan.empty.default")
        }
    }
}
