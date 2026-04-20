import SwiftUI
import UserNotifications
import BuddyPersona
import BuddyStats

struct SettingsScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var stats: PersonaStatsStore

    @Environment(\.dismiss) private var dismiss
    @AppStorage("buddy.hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue
    @AppStorage("buddy.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("buddy.petName") private var petName: String = "Buddy"
    @AppStorage("buddy.ownerName") private var ownerName: String = ""

    @State private var notificationStatus = "Unknown"
    @State private var showPicker = false
    @State private var showInfo = false
    @State private var confirmResetStats = false
    @State private var confirmDeleteChars = false
    @State private var infoMessage: LocalizedStringKey?
    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()

    private let repoURL = URL(string: "https://github.com/kingcos/claude-buddy-bridge-ios")!

    var body: some View {
        NavigationStack {
            ZStack {
                BuddyTheme.backgroundGradient(themePreset).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        petCard
                        themeCard
                        notificationCard
                        aboutCard
                        guideCard
                        dangerCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
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
            .sheet(isPresented: $showInfo) {
                InfoScreen()
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
            .alert("common.notice", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
                Button("common.ok", role: .cancel) { infoMessage = nil }
            } message: {
                if let m = infoMessage { Text(m) }
            }
        }
    }

    // MARK: - Cards

    private var petCard: some View {
        BuddyCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("settings.section.pet", systemImage: "pawprint.circle.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                HStack {
                    Text("settings.pet.petName")
                    Spacer()
                    TextField("Buddy", text: $petName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 140)
                }

                HStack {
                    Text("settings.pet.ownerName")
                    Spacer()
                    TextField("settings.pet.ownerPlaceholder", text: $ownerName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 140)
                }

                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Label("settings.pet.change", systemImage: "pawprint")
                        Spacer()
                        Text(currentSpeciesLabel)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showInfo = true
                } label: {
                    Label("settings.pet.info", systemImage: "info.circle")
                }
                .buttonStyle(.plain)

                statsSummary
            }
        }
    }

    private var statsSummary: some View {
        let s = stats.stats
        return VStack(alignment: .leading, spacing: 4) {
            Text("settings.pet.summary")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                statPill(label: "Lv", value: "\(s.level)")
                statPill(label: "approved", value: "\(s.approvals)")
                statPill(label: "denied", value: "\(s.denials)")
            }
        }
        .padding(.top, 4)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var themeCard: some View {
        BuddyCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("settings.section.theme", systemImage: "paintpalette")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                ForEach(BuddyThemePreset.allCases) { preset in
                    Button {
                        themePreset = preset.rawValue
                    } label: {
                        HStack {
                            Circle()
                                .fill(BuddyTheme.palette(preset.rawValue).shell)
                                .frame(width: 16, height: 16)
                            Text(themeName(for: preset))
                            Spacer()
                            if themePreset == preset.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BuddyTheme.palette(themePreset).highlight)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notificationCard: some View {
        BuddyCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("settings.section.notifications", systemImage: "bell.badge")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Toggle("settings.notifications.enable", isOn: $notificationsEnabled)
                    .tint(BuddyTheme.palette(themePreset).highlight)

                HStack {
                    Text("settings.notifications.status")
                    Spacer()
                    Text(notificationStatus)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        _ = await BuddyNotificationCenter.shared.requestAuthorizationIfNeeded()
                        await refreshNotificationStatus()
                    }
                } label: {
                    Label("settings.notifications.request", systemImage: "hand.raised")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BuddyTheme.palette(themePreset).button)
            }
        }
    }

    private var aboutCard: some View {
        BuddyCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("settings.section.about", systemImage: "info.circle")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                keyValue("settings.about.app", "Claude Buddy Bridge")
                keyValue("settings.about.version", appVersion)
                keyValue("settings.about.author", "kingcos")
                keyValue("settings.about.language", currentLanguageLabel)

                Link(destination: repoURL) {
                    Label("settings.about.repo", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(BuddyTheme.palette(themePreset).highlight)
            }
        }
    }

    private var guideCard: some View {
        BuddyCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("settings.section.guide", systemImage: "book")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Button {
                    hasOnboarded = false
                } label: {
                    Label("settings.guide.show", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var dangerCard: some View {
        BuddyCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("settings.section.danger", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)

                Button(role: .destructive) {
                    confirmResetStats = true
                } label: {
                    Label("pet.reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(role: .destructive) {
                    confirmDeleteChars = true
                } label: {
                    Label("pet.delete", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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

    private func keyValue(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
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

    private func themeName(for preset: BuddyThemePreset) -> String {
        switch preset {
        case .m5Orange: return String(localized: "settings.theme.orange")
        case .mint:     return String(localized: "settings.theme.mint")
        case .graphite: return String(localized: "settings.theme.graphite")
        case .coral:    return String(localized: "settings.theme.coral")
        }
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
