import SwiftUI
import BuddyStats

@main
struct ClaudeBuddyBridgeApp: App {
    @StateObject private var statsStore: PersonaStatsStore
    @StateObject private var model: BridgeAppModel
    @StateObject private var persona = PersonaController()

    init() {
        let store = PersonaStatsStore()
        _statsStore = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: BridgeAppModel(statsStore: store))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(model: model, persona: persona, stats: statsStore)
                .onAppear {
                    persona.bind(to: model)
                }
        }
    }
}

struct RootTabView: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    var body: some View {
        TabView {
            HomeScreen(model: model, persona: persona, stats: stats)
                .tabItem {
                    Label("Buddy", systemImage: "pawprint.fill")
                }

            ContentView(model: model)
                .tabItem {
                    Label("Terminal", systemImage: "terminal.fill")
                }
        }
    }
}
