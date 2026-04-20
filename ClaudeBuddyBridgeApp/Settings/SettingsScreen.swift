import SwiftUI
import UserNotifications

struct SettingsScreen: View {
    @AppStorage("buddy.hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue
    @AppStorage("buddy.notificationsEnabled") private var notificationsEnabled = true

    @State private var notificationStatus = "Unknown"

    private let repoURL = URL(string: "https://github.com/kingcos/claude-buddy-bridge-ios")!

    var body: some View {
        NavigationStack {
            ZStack {
                BuddyTheme.backgroundGradient(themePreset).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        themeCard
                        notificationCard
                        aboutCard
                        guideCard
                    }
                    .padding(16)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .task {
                await refreshNotificationStatus()
            }
        }
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
        case .m5Orange:
            return String(localized: "settings.theme.orange")
        case .mint:
            return String(localized: "settings.theme.mint")
        case .graphite:
            return String(localized: "settings.theme.graphite")
        case .coral:
            return String(localized: "settings.theme.coral")
        }
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
