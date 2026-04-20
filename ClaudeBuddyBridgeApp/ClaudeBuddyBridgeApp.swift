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
                    RootView(model: model, persona: persona, stats: statsStore)
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

struct RootView: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var currentPage: RootPage = .pet
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Group {
                if currentPage == .pet {
                    PetDeviceScreen(model: model, persona: persona, stats: stats)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    ContentView(model: model)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: currentPage)

            VStack {
                HStack {
                    Spacer()
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
                Spacer()
                MechanicalSwitch(page: $currentPage)
                    .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(model: model, stats: stats)
        }
    }
}
