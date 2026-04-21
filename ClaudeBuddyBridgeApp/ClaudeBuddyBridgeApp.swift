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
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    ContentView(model: model, persona: persona)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.28), value: currentPage)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TerminalStyle.ink)
                            .padding(10)
                            .background(TerminalStyle.lcdPanel.opacity(0.8), in: Circle())
                            .overlay(
                                Circle().stroke(TerminalStyle.inkDim.opacity(0.55), lineWidth: 1)
                            )
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
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                    guard abs(value.translation.width) > 60 else { return }
                    if value.translation.width < 0, currentPage == .pet {
                        withAnimation { currentPage = .terminal }
                    } else if value.translation.width > 0, currentPage == .terminal {
                        withAnimation { currentPage = .pet }
                    }
                }
        )
    }
}
