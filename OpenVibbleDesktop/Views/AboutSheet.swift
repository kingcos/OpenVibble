// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

// Legacy "About" sheet. Superseded by the About section inside SettingsTab;
// the dedicated About window scene was removed when the menu bar was
// redirected to the Settings tab. Left in the target because removing it
// from the Xcode project requires pbxproj surgery; safe to delete later.
struct AboutSheet: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    private let repoURL = URL(string: "https://github.com/kingcos/OpenVibble")!

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.tint)
                .padding(.top, 12)

            Text(appName)
                .font(.title2.weight(.semibold))

            Text(l10n.bundle.l("desktop.about.version", shortVersion, buildNumber))
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            LText("desktop.about.tagline")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            Divider().padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(key: "desktop.about.author", value: "kingcos")
                HStack {
                    LText("desktop.about.repo")
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Link(destination: repoURL) {
                        Text(repoURL.absoluteString)
                            .font(.system(.body, design: .monospaced))
                    }
                    Spacer()
                }
                infoRow(key: "desktop.about.license", value: "MPL-2.0")
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(action: { dismiss() }) { LText("desktop.btn.close") }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 360)
        .environment(\.localizationBundle, l10n.bundle)
    }

    private func infoRow(key: String, value: String) -> some View {
        HStack {
            LText(key)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "OpenVibble Desktop"
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
