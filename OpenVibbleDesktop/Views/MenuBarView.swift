// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import NUSCentral

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    let openMainWindow: () -> Void
    let openSettings: () -> Void

    var body: some View {
        Group {
            // Indicator dot + status text (unified wording with TopBar).
            // NOTE: MenuBarExtra in .menu style draws each row as an NSMenuItem,
            // so custom HStack layout is stripped. We render the dot as a leading
            // emoji in the text itself so it survives the menu rendering.
            // Leave font to system default so it matches sibling menu items
            // (previously .caption made it visibly smaller than "停止扫描" etc).
            Text("\(indicatorDot) \(statusText)")
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
            Button(action: openSettings) { LText("desktop.menu.settings") }
            Divider()
            Button(action: { NSApp.terminate(nil) }) { LText("desktop.menu.quit") }
                .keyboardShortcut("q")
        }
        .environment(\.localizationBundle, l10n.bundle)
    }

    /// Emoji indicator so it renders inside NSMenuItem text.
    private var indicatorDot: String {
        switch state.connection {
        case .connected: return "🟢"
        case .scanning, .connecting: return "🟡"
        case .error, .poweredOff, .unauthorized, .unsupported: return "🔴"
        default: return "⚪️"
        }
    }

    /// Same wording as TopBar in MainView so menu-bar and window stay consistent.
    private var statusText: String {
        switch state.connection {
        case .connected:
            let name = state.connectedName ?? l10n.bundle.l("desktop.value.none")
            return l10n.bundle.l("desktop.menu.summary.connected", name)
        case .scanning: return l10n.bundle.l("desktop.header.scanning")
        case .connecting: return l10n.bundle.l("desktop.header.connecting")
        case .disconnecting: return l10n.bundle.l("desktop.header.disconnecting")
        case .idle: return l10n.bundle.l("desktop.header.idle")
        case .poweredOff: return l10n.bundle.l("desktop.bt.off")
        case .unauthorized: return l10n.bundle.l("desktop.header.unauth")
        case .unsupported: return l10n.bundle.l("desktop.header.unsupported")
        case .unknown: return l10n.bundle.l("desktop.header.startup")
        case .error(let msg): return l10n.bundle.l("desktop.header.error", msg)
        }
    }
}
