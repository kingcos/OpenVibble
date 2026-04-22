// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UserNotifications
import BuddyPersona
import BuddyStats
import BuddyUI

struct SettingsScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var stats: PersonaStatsStore

    @Environment(\.dismiss) private var dismiss
    @AppStorage("buddy.hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("buddy.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("buddy.foregroundNotificationsEnabled") private var foregroundNotificationsEnabled = true
    @AppStorage("buddy.liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("home.showPowerButton") private var showPowerButton: Bool = true

    @State private var notificationStatus = "?"
    @State private var notificationsAuthorized = false
    @State private var showPicker = false
    @State private var confirmResetStats = false
    @State private var confirmDeleteChars = false
    @State private var infoMessage: LocalizedStringKey?
    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()
    private let repoURL = URL(string: "https://github.com/kingcos/OpenVibble")!
    private let authorURL = URL(string: "https://github.com/kingcos")!

    var body: some View {
        ZStack {
            TerminalBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerBar

                    TerminalPanel("settings.section.pet.lower") { petContent }
                    TerminalPanel("settings.section.interface.lower") { interfaceContent }
                    TerminalPanel("settings.section.alerts.lower") { alertsContent }
                    TerminalPanel("settings.section.about.lower") { aboutContent }
                    TerminalPanel(
                        "settings.section.guide.lower",
                        collapsible: true,
                        collapsedByDefault: true
                    ) { helpContent }
                    TerminalPanel(
                        "settings.section.danger.lower",
                        accent: .red,
                        collapsible: true,
                        collapsedByDefault: true
                    ) { dangerContent }
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .task { await refreshNotificationStatus() }
        .onAppear(perform: reloadInstalled)
        .sheet(isPresented: $showPicker) {
            SpeciesPickerSheet(
                selection: $selection,
                builtin: builtin,
                installed: installed,
                onClose: { showPicker = false }
            )
        }
        .alert("pet.reset.confirm", isPresented: $confirmResetStats) {
            Button("common.cancel", role: .cancel) {}
            Button("pet.reset.doIt", role: .destructive) {
                performFactoryReset()
                infoMessage = "pet.stats.resetOk"
            }
        } message: {
            Text("pet.reset.message")
        }
        .alert("pet.delete.confirm", isPresented: $confirmDeleteChars) {
            Button("common.cancel", role: .cancel) {}
            Button("pet.delete.doIt", role: .destructive) {
                let catalog = PersonaCatalog(rootURL: model.charactersRootURL)
                let ok = catalog.deleteAll()
                PersonaSelection.save(PersonaSelection.defaultSpecies)
                selection = PersonaSelection.defaultSpecies
                reloadInstalled()
                infoMessage = ok ? "pet.stats.deleteOk" : "pet.stats.deleteFail"
            }
        } message: {
            Text("pet.delete.message")
        }
        .alert(
            "common.notice",
            isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) { infoMessage = nil }
        } message: {
            if let m = infoMessage { Text(m) }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: "$")
                .font(TerminalStyle.mono(16, weight: .bold))
                .foregroundStyle(TerminalStyle.inkDim)
            Text("settings.title")
                .font(TerminalStyle.display(26))
                .tracking(2)
                .foregroundStyle(TerminalStyle.ink)
                .shadow(color: TerminalStyle.accent.opacity(0.45), radius: 0, x: 1.5, y: 1.5)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("common.done")
            }
            .buttonStyle(TerminalHeaderButtonStyle())
        }
    }

    // MARK: - Pet

    private var petContent: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Text("settings.species")
                    .foregroundStyle(TerminalStyle.ink)
                Spacer()
                Text(currentSpeciesLabel)
                    .foregroundStyle(TerminalStyle.inkDim)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TerminalStyle.inkDim)
            }
            .font(TerminalStyle.mono(12))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(TerminalStyle.lcdPanel.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TerminalStyle.inkDim.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Interface

    private var interfaceContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $showPowerButton) {
                Text("settings.interface.showPowerButton")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.ink)
            }
            .tint(TerminalStyle.accent)

            Text("settings.interface.showPowerButton.hint")
                .font(TerminalStyle.mono(10))
                .foregroundStyle(TerminalStyle.inkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Alerts (notifications + live activity)

    private var alertsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $notificationsEnabled) {
                HStack {
                    Text("settings.notifications.label")
                    Spacer()
                    Text(notificationStatus)
                        .foregroundStyle(TerminalStyle.inkDim)
                        .font(TerminalStyle.mono(10))
                }
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.ink)
            }
            .tint(TerminalStyle.accent)

            Toggle(isOn: $foregroundNotificationsEnabled) {
                Text("settings.notifications.foreground.label")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.ink)
            }
            .tint(TerminalStyle.accent)
            .disabled(!notificationsEnabled)
            .opacity(notificationsEnabled ? 1 : 0.5)

            Text("settings.notifications.foreground.hint")
                .font(TerminalStyle.mono(10))
                .foregroundStyle(TerminalStyle.inkDim)
                .fixedSize(horizontal: false, vertical: true)

            if !notificationsAuthorized {
                Button {
                    Task {
                        _ = await BuddyNotificationCenter.shared.requestAuthorizationIfNeeded()
                        await refreshNotificationStatus()
                    }
                } label: {
                    Text("settings.notifications.request")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TerminalHeaderButtonStyle(fill: true))
            }

            Divider()
                .overlay(TerminalStyle.inkDim.opacity(0.3))

            Toggle(isOn: $liveActivityEnabled) {
                Text("settings.liveActivity")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.ink)
            }
            .tint(TerminalStyle.accent)

            Text("settings.liveActivity.hint")
                .font(TerminalStyle.mono(10))
                .foregroundStyle(TerminalStyle.inkDim)
        }
    }

    // MARK: - Help

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ButtonCheatSheet()

            Text("settings.help.reconnectHint")
                .font(TerminalStyle.mono(11, weight: .bold))
                .foregroundStyle(TerminalStyle.bad)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                hasOnboarded = false
            } label: {
                rowLabel(
                    text: "settings.guide.show",
                    trailing: "arrow.up.right",
                    tint: TerminalStyle.ink
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                aboutRow("settings.about.app", "OpenVibble")
                aboutRow("settings.about.version", appVersion)
                authorRow
                aboutRow("settings.about.language", currentLanguageLabel)
            }

            Link(destination: repoURL) {
                rowLabel(
                    text: "settings.github",
                    trailing: "arrow.up.right",
                    tint: TerminalStyle.ink
                )
            }
        }
    }

    private func aboutRow(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(TerminalStyle.inkDim)
            Spacer()
            Text(value)
                .foregroundStyle(TerminalStyle.ink)
        }
        .font(TerminalStyle.mono(12))
    }

    private var authorRow: some View {
        HStack {
            Text("settings.about.author")
                .foregroundStyle(TerminalStyle.inkDim)
            Spacer()
            Link(destination: authorURL) {
                HStack(spacing: 4) {
                    Text(verbatim: "kingcos")
                        .underline()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(TerminalStyle.ink)
            }
        }
        .font(TerminalStyle.mono(12))
    }

    private func rowLabel(
        text: LocalizedStringKey,
        trailing: String,
        tint: Color
    ) -> some View {
        HStack {
            Text(text)
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 12, weight: .bold))
        }
        .font(TerminalStyle.mono(12, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(TerminalStyle.lcdPanel.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Danger

    private var dangerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(role: .destructive) {
                confirmResetStats = true
            } label: {
                rowLabel(
                    text: "pet.reset",
                    trailing: "arrow.counterclockwise",
                    tint: TerminalStyle.bad
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                confirmDeleteChars = true
            } label: {
                rowLabel(
                    text: "pet.delete",
                    trailing: "trash",
                    tint: installed.isEmpty ? TerminalStyle.inkDim : TerminalStyle.bad
                )
            }
            .buttonStyle(.plain)
            .disabled(installed.isEmpty)
        }
    }

    // MARK: - Helpers

    private var currentSpeciesLabel: String {
        switch selection {
        case .asciiCat:
            return "ASCII"
        case .asciiSpecies(let idx):
            if let name = PersonaSpeciesCatalog.name(at: idx) {
                return "ASCII (\(name.capitalized))"
            }
            return "ASCII #\(idx)"
        case .builtin(let name), .installed(let name):
            return name.capitalized
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = (info["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    private var currentLanguageLabel: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code.hasPrefix("zh") ? "中文" : "English"
    }

    private func reloadInstalled() {
        let catalog = PersonaCatalog(rootURL: model.charactersRootURL)
        installed = catalog.listInstalled()
        selection = PersonaSelection.load()
    }

    private func performFactoryReset() {
        let defaults = UserDefaults.standard
        for key in [
            "buddy.hasOnboarded",
            "buddy.notificationsEnabled",
            "buddy.foregroundNotificationsEnabled",
            "buddy.liveActivityEnabled",
            "bridge.displayName",
            "home.showPowerButton"
        ] {
            defaults.removeObject(forKey: key)
        }
        stats.reset()
        PersonaSelection.save(PersonaSelection.defaultSpecies)
        selection = PersonaSelection.defaultSpecies
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = String(localized: "settings.notifications.status.enabled")
            notificationsAuthorized = true
        case .denied:
            notificationStatus = String(localized: "settings.notifications.status.denied")
            notificationsAuthorized = false
        case .notDetermined:
            notificationStatus = String(localized: "settings.notifications.status.notDetermined")
            notificationsAuthorized = false
        @unknown default:
            notificationStatus = String(localized: "settings.notifications.status.unknown")
            notificationsAuthorized = false
        }
    }
}
