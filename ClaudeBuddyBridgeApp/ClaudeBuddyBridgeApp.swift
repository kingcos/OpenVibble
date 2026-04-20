import SwiftUI
import BuddyStats

@main
struct ClaudeBuddyBridgeApp: App {
    @StateObject private var statsStore: PersonaStatsStore
    @StateObject private var model: BridgeAppModel
    @StateObject private var persona = PersonaController()
    @StateObject private var motion = MotionSensor()
    @AppStorage("buddy.hasOnboarded") private var hasOnboarded: Bool = false

    init() {
        let store = PersonaStatsStore()
        _statsStore = StateObject(wrappedValue: store)
        _model = StateObject(wrappedValue: BridgeAppModel(statsStore: store))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    RootTabView(model: model, persona: persona, stats: statsStore)
                } else {
                    OnboardingScreen {
                        hasOnboarded = true
                    }
                }
            }
            .onAppear {
                persona.bind(to: model, motion: motion, stats: statsStore)
                motion.start()
            }
            .onDisappear { motion.stop() }
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
                    Label("tab.buddy", systemImage: "pawprint.fill")
                }

            ContentView(model: model)
                .tabItem {
                    Label("tab.terminal", systemImage: "terminal.fill")
                }

            SettingsScreen()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape.fill")
                }
        }
    }
}
