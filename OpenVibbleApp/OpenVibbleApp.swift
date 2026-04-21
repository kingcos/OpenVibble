import SwiftUI
import BuddyStats

@main
struct OpenVibbleApp: App {
    @StateObject private var statsStore: PersonaStatsStore
    @StateObject private var model: BridgeAppModel
    @StateObject private var persona = PersonaController()
    @StateObject private var motion = MotionSensor()
    @StateObject private var navigation = NavigationCoordinator()
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
                    HomeScreen(model: model, persona: persona, stats: statsStore)
                        .environmentObject(navigation)
                } else {
                    OnboardingScreen(model: model) {
                        hasOnboarded = true
                    }
                }
            }
            .onAppear {
                persona.bind(to: model, motion: motion, stats: statsStore)
                motion.start()
            }
            .onDisappear { motion.stop() }
            .onOpenURL { url in
                navigation.handle(url: url)
            }
        }
    }
}
