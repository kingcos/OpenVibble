// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import NUSCentral

struct ScanSheet: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var l10n = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            footer
        }
        .frame(minWidth: 460, minHeight: 420)
        .onAppear { state.startScan() }
        .onDisappear { state.stopScan() }
        .environment(\.localizationBundle, l10n.bundle)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isScanning ? "antenna.radiowaves.left.and.right" : "dot.radiowaves.right")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, isActive: isScanning)
            VStack(alignment: .leading, spacing: 2) {
                LText("desktop.scan.title").font(.headline)
                LText("desktop.scan.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isScanning {
                ProgressView().controlSize(.small)
            }
            Button(action: toggleScan) {
                Text(scanButtonKey, bundle: l10n.bundle)
            }
            .controlSize(.regular)
        }
        .padding(16)
    }

    @ViewBuilder
    private var content: some View {
        if state.discovered.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text(emptyHint)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selected) {
                ForEach(state.discovered) { p in
                    deviceRow(p)
                        .tag(p.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            connect(p)
                        }
                }
            }
            .listStyle(.inset)
            .alternatingRowBackgrounds()
        }
    }

    private func deviceRow(_ p: DiscoveredPeripheral) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 15))
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.body.weight(.medium))
                Text(p.id.uuidString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(l10n.bundle.l("desktop.scan.rssi", p.rssi))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                rssiBars(p.rssi)
            }
            Button(action: { connect(p) }) { LText("desktop.btn.connect") }
                .controlSize(.small)
        }
        .padding(.vertical, 6)
    }

    private func rssiBars(_ rssi: Int) -> some View {
        let level: Int = {
            if rssi >= -55 { return 4 }
            if rssi >= -70 { return 3 }
            if rssi >= -85 { return 2 }
            return 1
        }()
        return HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i < level ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: CGFloat(5 + i * 2))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(l10n.bundle.l("desktop.scan.count", state.discovered.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: { dismiss() }) { LText("desktop.btn.cancel") }
                .keyboardShortcut(.cancelAction)
            Button(action: connectSelected) { LText("desktop.btn.connect") }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
        }
        .padding(16)
    }

    private func connectSelected() {
        guard let id = selected,
              let p = state.discovered.first(where: { $0.id == id }) else { return }
        connect(p)
    }

    private func connect(_ p: DiscoveredPeripheral) {
        state.connect(p)
        dismiss()
    }

    private func toggleScan() {
        if isScanning {
            state.stopScan()
        } else {
            state.startScan()
        }
    }

    private var isScanning: Bool {
        if case .scanning = state.connection { return true }
        return false
    }

    private var scanButtonKey: LocalizedStringKey {
        isScanning ? "desktop.btn.stop" : "desktop.btn.scan"
    }

    private var emptyHint: String {
        switch state.connection {
        case .poweredOff: return l10n.bundle.l("desktop.bt.off")
        case .unauthorized: return l10n.bundle.l("desktop.scan.empty.unauth")
        case .unsupported: return l10n.bundle.l("desktop.scan.empty.unsupported")
        case .scanning: return l10n.bundle.l("desktop.scan.empty.scanning")
        default: return l10n.bundle.l("desktop.scan.empty.default")
        }
    }
}
