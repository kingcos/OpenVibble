// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
        // Register the actionable "prompt" notification category and install
        // the delegate before the first scene is built. Apple requires the
        // delegate to be set before app-launch-time callbacks fire, otherwise
        // action taps that cold-start the app would be delivered to nobody.
        BuddyNotificationCenter.shared.configure()
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
