// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import AppKit
import NUSCentral

@main
struct OpenVibbleDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("OpenVibble Desktop", id: "main") {
            MainView()
                .environmentObject(state)
                .frame(minWidth: 560, minHeight: 520)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView(
                openMainWindow: { presentMainWindow() },
                openSettings: { presentMainWindow(requestedTab: .settings) }
            )
            .environmentObject(state)
        } label: {
            Image(systemName: menuBarIcon(for: state.connection))
        }
        .menuBarExtraStyle(.menu)
    }

    private func presentMainWindow(requestedTab: MainView.Tab? = nil) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        if let tab = requestedTab {
            NotificationCenter.default.post(name: .openVibbleSelectTab, object: tab)
        }
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

/// Hybrid Dock+MenuBar: app starts as `.regular` so AppKit keeps the main
/// window across system events like the Bluetooth TCC prompt. When the user
/// closes the last user-facing window we swap to `.accessory` so the Dock
/// icon disappears and only the menu bar extra remains. Reopening the window
/// from the menu bar flips the policy back to `.regular`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func windowWillClose(_ note: Notification) {
        // Defer so the closing window reports isVisible == false before counting.
        DispatchQueue.main.async {
            let stillVisible = NSApp.windows.contains { win in
                win.isVisible && win.canBecomeMain
            }
            if !stillVisible {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

extension Notification.Name {
    static let openVibbleSelectTab = Notification.Name("openvibble.selectTab")
}
