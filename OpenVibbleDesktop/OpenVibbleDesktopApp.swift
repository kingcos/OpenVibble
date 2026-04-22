import SwiftUI
import NUSCentral

@main
struct OpenVibbleDesktopApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("OpenVibbleDesktop", id: "main") {
            MainView()
                .environmentObject(state)
                .frame(minWidth: 560, minHeight: 520)
        }
        .windowResizability(.contentSize)

        Window("About OpenVibbleDesktop", id: "about") {
            AboutSheet()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarView(
                openMainWindow: { openWindow(id: "main") },
                openAboutWindow: { openWindow(id: "about") }
            )
            .environmentObject(state)
        } label: {
            Image(systemName: menuBarIcon(for: state.connection))
        }
        .menuBarExtraStyle(.menu)
    }

    private func menuBarIcon(for state: CentralConnectionState) -> String {
        switch state {
        case .connected: return "dot.radiowaves.left.and.right"
        case .scanning, .connecting: return "antenna.radiowaves.left.and.right"
        case .poweredOff, .unauthorized, .unsupported, .error: return "exclamationmark.triangle"
        default: return "dot.radiowaves.right"
        }
    }
}
