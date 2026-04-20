import SwiftUI

@main
struct ClaudeBuddyBridgeApp: App {
    @StateObject private var model = BridgeAppModel()
    @StateObject private var persona = PersonaController()

    var body: some Scene {
        WindowGroup {
            RootTabView(model: model, persona: persona)
                .onAppear {
                    persona.bind(to: model)
                }
        }
    }
}

struct RootTabView: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController

    var body: some View {
        TabView {
            HomeScreen(model: model, persona: persona)
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
