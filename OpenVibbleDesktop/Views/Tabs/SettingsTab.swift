import SwiftUI
import AppKit

struct SettingsTab: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @State private var testPanelExpanded = false

    private let repoURL = URL(string: "https://github.com/kingcos/OpenVibble")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                languageSection
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
            LText("desktop.tab.testPanel")
                .font(.headline)
        }
        .padding(.horizontal, 2)
    }

    private var hero: some View {
        HStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.tint)
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

    private var aboutSection: some View {
        GroupBox(label: LText("desktop.settings.about")) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(labelKey: "desktop.about.author", value: "kingcos")
                HStack(alignment: .firstTextBaseline) {
                    LText("desktop.about.repo")
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Link(destination: repoURL) {
                        Text(repoURL.absoluteString)
                            .font(.system(.body, design: .monospaced))
                    }
                    Spacer()
                }
                infoRow(labelKey: "desktop.about.license", value: "Apache-2.0")
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoRow(labelKey: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            LText(labelKey)
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
            ?? "OpenVibbleDesktop"
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
