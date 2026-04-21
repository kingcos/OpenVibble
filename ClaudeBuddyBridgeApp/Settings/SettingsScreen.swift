import SwiftUI
import UserNotifications
import BuddyPersona
import BuddyStats

struct SettingsScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var stats: PersonaStatsStore

    @Environment(\.dismiss) private var dismiss
    @AppStorage("buddy.hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("buddy.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("buddy.showScanline") private var showScanline = true
    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.ownerName") private var ownerName: String = ""
    @AppStorage("bridge.displayName") private var bridgeDisplayName: String = ""
    @AppStorage("bridge.autoStartBLE") private var autoStartBLE: Bool = true

    @State private var notificationStatus = "?"
    @State private var showPicker = false
    @State private var confirmResetStats = false
    @State private var confirmDeleteChars = false
    @State private var infoMessage: LocalizedStringKey?
    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()

    private let repoURL = URL(string: "https://github.com/kingcos/claude-buddy-bridge-ios")!

    var body: some View {
        ZStack {
            TerminalBackground(showScanline: showScanline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerBar

                    TerminalPanel("buddy --profile") { profileContent }
                    TerminalPanel("buddy --display") { displayContent }
                    TerminalPanel("about") { aboutContent }
                    TerminalPanel("danger", accent: .red) { dangerContent }
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
        .confirmationDialog(
            Text("pet.reset.confirm"),
            isPresented: $confirmResetStats,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                stats.reset()
                infoMessage = "pet.stats.resetOk"
            } label: { Text("pet.reset.doIt") }
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: {
            Text("pet.reset.message")
        }
        .confirmationDialog(
            Text("pet.delete.confirm"),
            isPresented: $confirmDeleteChars,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                let catalog = PersonaCatalog(rootURL: model.charactersRootURL)
                let ok = catalog.deleteAll()
                PersonaSelection.save(PersonaSelection.defaultSpecies)
                selection = PersonaSelection.defaultSpecies
                reloadInstalled()
                infoMessage = ok ? "pet.stats.deleteOk" : "pet.stats.deleteFail"
            } label: { Text("pet.delete.doIt") }
            Button(role: .cancel) {} label: { Text("common.cancel") }
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
        HStack {
            Text("$ settings")
                .font(TerminalStyle.mono(16, weight: .bold))
                .foregroundStyle(.green)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("common.done")
            }
            .buttonStyle(TerminalHeaderButtonStyle())
        }
    }

    // MARK: - Profile panel (identity + bridge)

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("pet", text: $petName, placeholder: "Buddy")
            labeledField("owner", text: $ownerName, placeholder: String(localized: "settings.pet.ownerPlaceholder"))
            labeledField("ble",   text: $bridgeDisplayName, placeholder: "Claude-iPhone")

            Button {
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text("species")
                        .foregroundStyle(.green.opacity(0.6))
                    Text(currentSpeciesLabel)
                        .foregroundStyle(.green)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green.opacity(0.6))
                }
                .font(TerminalStyle.mono(12))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Toggle(isOn: $autoStartBLE) {
                Text("auto-advertise")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(.green)
            }
            .tint(.green)
        }
    }

    private func labeledField(_ tag: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Text(tag)
                .frame(width: 56, alignment: .leading)
                .foregroundStyle(.green.opacity(0.6))
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(.green)
                .tint(.green)
        }
        .font(TerminalStyle.mono(12))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Display (scanline + notifications merged)

    private var displayContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $showScanline) {
                Text("scanline")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(.green)
            }
            .tint(.green)

            Toggle(isOn: $notificationsEnabled) {
                HStack {
                    Text("notifications")
                    Spacer()
                    Text(notificationStatus)
                        .foregroundStyle(.green.opacity(0.6))
                        .font(TerminalStyle.mono(10))
                }
                .font(TerminalStyle.mono(12))
                .foregroundStyle(.green)
            }
            .tint(.green)

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
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            aboutRow("name", "Claude Buddy Bridge")
            aboutRow("ver", appVersion)
            aboutRow("by",  "kingcos")
            aboutRow("lang", currentLanguageLabel)

            Link(destination: repoURL) {
                HStack {
                    Text("github →")
                        .foregroundStyle(.green)
                    Spacer()
                }
                .font(TerminalStyle.mono(12, weight: .semibold))
                .padding(.top, 4)
            }

            Button {
                hasOnboarded = false
            } label: {
                HStack {
                    Text("settings.guide.show")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.green.opacity(0.8))
                .font(TerminalStyle.mono(12))
            }
            .buttonStyle(.plain)
        }
    }

    private func aboutRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(.green.opacity(0.6))
            Spacer()
            Text(value)
                .foregroundStyle(.green.opacity(0.9))
        }
        .font(TerminalStyle.mono(12))
    }

    // MARK: - Danger

    private var dangerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(role: .destructive) {
                confirmResetStats = true
            } label: {
                HStack {
                    Text("pet.reset")
                    Spacer()
                    Image(systemName: "arrow.counterclockwise")
                }
                .font(TerminalStyle.mono(12, weight: .semibold))
                .foregroundStyle(.red.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                confirmDeleteChars = true
            } label: {
                HStack {
                    Text("pet.delete")
                    Spacer()
                    Image(systemName: "trash")
                }
                .font(TerminalStyle.mono(12, weight: .semibold))
                .foregroundStyle(.red.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var currentSpeciesLabel: String {
        switch selection {
        case .asciiCat:
            return String(localized: "species.ascii.cat")
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

    @MainActor
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = String(localized: "settings.notifications.status.enabled")
        case .denied:
            notificationStatus = String(localized: "settings.notifications.status.denied")
        case .notDetermined:
            notificationStatus = String(localized: "settings.notifications.status.notDetermined")
        @unknown default:
            notificationStatus = String(localized: "settings.notifications.status.unknown")
        }
    }
}
