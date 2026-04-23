// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    @State private var selection: Tab = .hooks
    @State private var showScanSheet = false

    // Overview was folded into the Hooks tab, so the enum no longer lists it.
    enum Tab: Hashable { case hooks, bridge, settings }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showScanSheet: $showScanSheet)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            if let detail = state.lastErrorDetail {
                ErrorBanner(detail: detail) { state.clearLastError() }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            Divider()
            TabView(selection: $selection) {
                HooksTab()
                    .tabItem { Label { LText("desktop.tab.hooks") } icon: { Image(systemName: "link") } }
                    .tag(Tab.hooks)
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
        .onReceive(NotificationCenter.default.publisher(for: .openVibbleSelectTab)) { note in
            if let tab = note.object as? Tab { selection = tab }
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

private struct ErrorBanner: View {
    let detail: String
    let onDismiss: () -> Void
    @State private var expanded = false
    @ObservedObject private var l10n = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                LText("desktop.error.banner.title")
                    .font(.callout.weight(.medium))
                Spacer()
                Button(action: { expanded.toggle() }) {
                    LText(expanded ? "desktop.error.banner.hide" : "desktop.error.banner.show")
                }
                .buttonStyle(.borderless)
                Button(action: copy) { LText("desktop.error.banner.copy") }
                    .buttonStyle(.borderless)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            Text(headline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if expanded {
                ScrollView {
                    Text(detail)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var headline: String {
        detail.split(separator: "\n").first.map(String.init) ?? detail
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(detail, forType: .string)
    }
}
