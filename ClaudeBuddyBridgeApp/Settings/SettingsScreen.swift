import SwiftUI

struct SettingsScreen: View {
    @AppStorage("buddy.hasOnboarded") private var hasOnboarded: Bool = false

    private let repoURL = URL(string: "https://github.com/kingcos/claude-buddy-bridge-ios")!

    var body: some View {
        NavigationStack {
            ZStack {
                BuddyTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    aboutSection
                    languageSection
                    guideSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("settings.about.app")
                Spacer()
                Text("Claude Buddy Bridge").foregroundStyle(.secondary)
            }
            HStack {
                Text("settings.about.version")
                Spacer()
                Text(appVersion).foregroundStyle(.secondary).font(.system(.body, design: .monospaced))
            }
            HStack {
                Text("settings.about.author")
                Spacer()
                Text("kingcos").foregroundStyle(.secondary)
            }
            Link(destination: repoURL) {
                HStack {
                    Text("settings.about.repo")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        } header: {
            Text("settings.section.about")
        }
    }

    private var languageSection: some View {
        Section {
            HStack {
                Text("settings.about.language")
                Spacer()
                Text(currentLanguageLabel).foregroundStyle(.secondary)
            }
            Text("settings.about.language.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var guideSection: some View {
        Section {
            Button {
                hasOnboarded = false
            } label: {
                HStack {
                    Label("settings.guide.show", systemImage: "sparkles")
                    Spacer()
                }
            }
        } header: {
            Text("settings.section.guide")
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
}
