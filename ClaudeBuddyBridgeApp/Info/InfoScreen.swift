import SwiftUI

struct InfoScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                aboutPage
                    .tabItem { Label("About", systemImage: "info.circle") }
                gesturesPage
                    .tabItem { Label("Gestures", systemImage: "hand.tap") }
                claudePage
                    .tabItem { Label("Claude", systemImage: "sparkles") }
                creditsPage
                    .tabItem { Label("Credits", systemImage: "heart") }
            }
            .navigationTitle("Info")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var aboutPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Claude Buddy Bridge")
                    .font(.title2).bold()
                Text("Your iPhone becomes Claude Desktop's Hardware Buddy over BLE. Watch your buddy react to sessions, approve permissions, and level up as tokens accumulate.")
                Text("This iOS port replaces the ESP32 firmware — no extra hardware required.")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var gesturesPage: some View {
        List {
            Section("Device Gestures") {
                row("Shake", "Dizzy animation (2s)")
                row("Face-down 3s", "Sleep — accumulates nap time")
                row("Face-up again", "Wake back to idle / busy")
            }
            Section("Screen Gestures") {
                row("Tap buddy", "Tap feedback")
                row("Long-press buddy", "Main menu")
                row("Pawprint icon", "Choose species")
            }
        }
    }

    private var claudePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Claude Desktop").font(.title2).bold()
                Text("Pair this app from Claude Desktop's Hardware Buddy panel. Advertising uses the Nordic UART Service. iPhone name must start with \"Claude\" — set it in iOS Settings → General → About → Name.")
                Text("When the bridge sends a character pack, it lands in Application Support and appears in the species picker automatically.")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private var creditsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Credits").font(.title2).bold()
                Text("Original ESP32 firmware + protocol: claude-desktop-buddy.")
                Text("ASCII cat sprites ported from the firmware's buddies/cat.cpp.")
                Text("GIF packs are user-installed through Claude Desktop.")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(.body, design: .monospaced))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
