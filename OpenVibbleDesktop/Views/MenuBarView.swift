import SwiftUI
import NUSCentral

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    let openMainWindow: () -> Void
    let openAboutWindow: () -> Void

    var body: some View {
        Group {
            Text(summaryLine)
                .font(.caption)
            Divider()

            switch state.connection {
            case .connected:
                Button(action: { state.disconnect() }) { LText("desktop.btn.disconnect") }
            case .scanning:
                Button(action: { state.stopScan() }) { LText("desktop.menu.scan.stop") }
            default:
                Button(action: { state.startScan() }) { LText("desktop.menu.scan.start") }
            }

            Button(action: openMainWindow) { LText("desktop.menu.open") }
            Button(action: openAboutWindow) { LText("desktop.about") }
            Divider()
            Button(action: { NSApp.terminate(nil) }) { LText("desktop.menu.quit") }
                .keyboardShortcut("q")
        }
        .environment(\.localizationBundle, l10n.bundle)
    }

    private var summaryLine: String {
        switch state.connection {
        case .connected:
            let name = state.connectedName ?? "Claude"
            return l10n.bundle.l("desktop.menu.summary.connected", name)
        case .scanning:
            return l10n.bundle.l("desktop.menu.summary.scanning")
        case .connecting:
            return l10n.bundle.l("desktop.header.connecting")
        case .poweredOff:
            return l10n.bundle.l("desktop.bt.off")
        case .unauthorized:
            return l10n.bundle.l("desktop.header.unauth")
        case .unsupported:
            return l10n.bundle.l("desktop.header.unsupported")
        case .error(let msg):
            return l10n.bundle.l("desktop.header.error", msg)
        default:
            return l10n.bundle.l("desktop.header.idle")
        }
    }
}
