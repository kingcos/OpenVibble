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
                    RootPagerView(model: model, persona: persona, stats: statsStore)
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

struct RootPagerView: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var showSettings = false
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                PetDeviceScreen(model: model, persona: persona, stats: stats)
                ContentView(model: model)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel(Text("settings.title"))
            .padding(.top, 8)
            .padding(.trailing, 14)
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(model: model, stats: stats)
        }
    }
}
