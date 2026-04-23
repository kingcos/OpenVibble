// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import AppKit

struct SettingsTab: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @EnvironmentObject private var state: AppState
    @State private var testPanelExpanded = false

    private let repoURL = URL(string: "https://github.com/kingcos/OpenVibble")!
    private let authorURL = URL(string: "https://github.com/kingcos")!
    private let authorXURL = URL(string: "https://x.com/kingcos_v")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                languageSection
                scanFilterSection
                aboutSection
                testPanelSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var testPanelSection: some View {
        DisclosureGroup(isExpanded: $testPanelExpanded) {
            TestPanelTab()
                .padding(.top, 8)
        } label: {
            // Tap anywhere on the row (not just the chevron) to toggle.
            LText("desktop.tab.testPanel")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        testPanelExpanded.toggle()
                    }
                }
        }
        .padding(.horizontal, 2)
    }

    private var hero: some View {
        HStack(spacing: 14) {
            // Use the bundle's actual app icon instead of an SF Symbol so the
            // About screen mirrors what users see in Finder/Dock.
            appIconImage
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(appName)
                    .font(.title2.weight(.semibold))
                Text(l10n.bundle.l("desktop.about.version", shortVersion, buildNumber))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                LText("desktop.about.tagline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var languageSection: some View {
        GroupBox(label: LText("desktop.settings.language")) {
            Picker(selection: Binding(
                get: { l10n.language },
                set: { l10n.set($0) }
            )) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.titleKey, bundle: l10n.bundle).tag(lang)
                }
            } label: {
                LText("desktop.settings.language")
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scanFilterSection: some View {
        GroupBox(label: LText("desktop.settings.scan")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $state.useCustomScanPrefix) {
                    LText("desktop.settings.scan.custom")
                }
                .toggleStyle(.checkbox)

                if state.useCustomScanPrefix {
                    TextField(
                        l10n.bundle.l("desktop.settings.scan.placeholder"),
                        text: $state.customScanPrefix
                    )
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)

                    LText("desktop.settings.scan.help")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutSection: some View {
        GroupBox(label: LText("desktop.settings.about")) {
            VStack(alignment: .leading, spacing: 8) {
                // Author: clickable Link to kingcos's GitHub profile, with
                // a trailing "(X)" link pointing at the @kingcos_v X account.
                labeledRow("desktop.about.author") {
                    HStack(spacing: 6) {
                        Link(destination: authorURL) {
                            Text("kingcos")
                                .font(.system(.body, design: .monospaced))
                        }
                        Link(destination: authorXURL) {
                            Text("(X)")
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                // Repo: clickable Link; wrap long URL onto multiple lines.
                labeledRow("desktop.about.repo") {
                    Link(destination: repoURL) {
                        Text(repoURL.absoluteString)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // License: plain text, selectable so it can be copied.
                labeledRow("desktop.about.license") {
                    Text("MPL-2.0")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Selecting plain text in the section (version, author, license
            // values) is enabled per-element; this lets users copy the label
            // key labels as well since many reference the same layout.
            .textSelection(.enabled)
        }
    }

    /// Shared row layout: localized label on the left, arbitrary content on
    /// the right. Right side is allowed to wrap vertically.
    private func labeledRow<Content: View>(_ labelKey: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            LText(labelKey)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Loads the running app's icon. NSApp.applicationIconImage is populated
    /// once the bundle is registered with LaunchServices; for safety we fall
    /// back to the AppIcon asset or a generic SF Symbol when unavailable
    /// (e.g. SwiftUI preview, unsigned build).
    private var appIconImage: Image {
        let ns = NSApp?.applicationIconImage
            ?? NSImage(named: "AppIcon")
            ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
            ?? NSImage()
        return Image(nsImage: ns)
    }
}
