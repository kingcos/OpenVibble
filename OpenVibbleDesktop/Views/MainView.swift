import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    @State private var selection: Tab = .overview
    @State private var showScanSheet = false

    enum Tab: Hashable { case overview, hooks, testPanel, bridge, settings }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showScanSheet: $showScanSheet)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            Divider()
            TabView(selection: $selection) {
                OverviewTab()
                    .tabItem { Label { LText("desktop.tab.overview") } icon: { Image(systemName: "gauge") } }
                    .tag(Tab.overview)
                HooksTab()
                    .tabItem { Label { LText("desktop.tab.hooks") } icon: { Image(systemName: "link") } }
                    .tag(Tab.hooks)
                TestPanelTab()
                    .tabItem { Label { LText("desktop.tab.testPanel") } icon: { Image(systemName: "wrench.and.screwdriver") } }
                    .tag(Tab.testPanel)
                BridgeDocsTab()
                    .tabItem { Label { LText("desktop.tab.bridge") } icon: { Image(systemName: "doc.plaintext") } }
                    .tag(Tab.bridge)
                SettingsTab()
                    .tabItem { Label { LText("desktop.tab.settings") } icon: { Image(systemName: "gearshape") } }
                    .tag(Tab.settings)
            }
        }
        .environment(\.localizationBundle, l10n.bundle)
        .sheet(isPresented: $showScanSheet) {
            ScanSheet().environmentObject(state).environment(\.localizationBundle, l10n.bundle)
        }
    }
}

private struct TopBar: View {
    @EnvironmentObject var state: AppState
    @Binding var showScanSheet: Bool
    @ObservedObject var l10n = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(indicator)
                .frame(width: 10, height: 10)
            Text(label).font(.headline)
            Spacer()
            if isConnected {
                Button(action: { state.disconnect() }) { LText("desktop.btn.disconnect") }
            } else {
                Button(action: {
                    state.startScan()
                    showScanSheet = true
                }) { LText("desktop.btn.connect") }
            }
        }
    }

    private var isConnected: Bool {
        if case .connected = state.connection { return true }
        return false
    }

    private var label: String {
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

    private var indicator: Color {
        switch state.connection {
        case .connected: return .blue
        case .scanning, .connecting: return .orange
        case .error, .poweredOff, .unauthorized, .unsupported: return .red
        default: return .gray
        }
    }
}
