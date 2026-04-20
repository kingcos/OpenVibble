import SwiftUI

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BuddyTheme.backgroundGradient.ignoresSafeArea()
                TabView {
                    aboutPage
                        .tabItem { Label("info.tab.about", systemImage: "info.circle") }
                    gesturesPage
                        .tabItem { Label("info.tab.gestures", systemImage: "hand.tap") }
                    claudePage
                        .tabItem { Label("info.tab.claude", systemImage: "sparkles") }
                    creditsPage
                        .tabItem { Label("info.tab.credits", systemImage: "heart") }
                }
            }
            .navigationTitle("info.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var aboutPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("info.about.heading")
                    .font(.system(.title2, design: .rounded)).bold()
                Text("info.about.body1")
                Text("info.about.body2")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var gesturesPage: some View {
        List {
            Section {
                row(titleKey: "info.gestures.shake.title", detailKey: "info.gestures.shake.detail")
                row(titleKey: "info.gestures.facedown.title", detailKey: "info.gestures.facedown.detail")
                row(titleKey: "info.gestures.wake.title", detailKey: "info.gestures.wake.detail")
            } header: {
                Text("info.gestures.device")
            }
            Section {
                row(titleKey: "info.gestures.tap.title", detailKey: "info.gestures.tap.detail")
                row(titleKey: "info.gestures.long.title", detailKey: "info.gestures.long.detail")
                row(titleKey: "info.gestures.paw.title", detailKey: "info.gestures.paw.detail")
            } header: {
                Text("info.gestures.screen")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var claudePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("info.claude.heading")
                    .font(.system(.title2, design: .rounded)).bold()
                Text("info.claude.body1")
                Text("info.claude.body2")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var creditsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("info.credits.heading")
                    .font(.system(.title2, design: .rounded)).bold()
                Text("info.credits.body1")
                Text("info.credits.body2")
                Text("info.credits.body3")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(titleKey: LocalizedStringKey, detailKey: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey).font(.system(.body, design: .monospaced))
            Text(detailKey).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
