import SwiftUI
import BuddyPersona
import BuddyStats
import BuddyUI
import NUSPeripheral

struct HomeScreen: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController
    @ObservedObject var stats: PersonaStatsStore

    @State private var selection: PersonaSpeciesID = PersonaSelection.load()
    @State private var installed: [InstalledPersona] = []
    @State private var showPicker = false
    @State private var showMenu = false
    @State private var showStats = false
    @State private var showInfo = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.1), Color(red: 0.02, green: 0.03, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                header
                BuddyHUD(stats: stats.stats, energyTier: stats.energyTier())
                Spacer()
                buddyRenderer
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 160)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.6) { showMenu = true }
                Text(persona.state.slug.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .tracking(3)
                Spacer()
                summaryRow
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: reloadInstalled)
        .onChange(of: model.lastInstalledCharacter) { _, newValue in
            reloadInstalled()
            if let newValue {
                selection = .installed(name: newValue)
                PersonaSelection.save(selection)
            }
        }
        .sheet(isPresented: $showPicker) {
            SpeciesPickerSheet(
                selection: $selection,
                installed: installed,
                onClose: { showPicker = false }
            )
        }
        .sheet(isPresented: $showMenu) {
            MainMenuSheet(
                onOpenStats: { showStats = true },
                onOpenInfo: { showInfo = true },
                onOpenPicker: { showPicker = true }
            )
        }
        .sheet(isPresented: $showStats) {
            PetStatsScreen(stats: stats)
        }
        .sheet(isPresented: $showInfo) {
            InfoScreen()
        }
    }

    @ViewBuilder
    private var buddyRenderer: some View {
        switch resolvedPersona() {
        case .ascii:
            ASCIIBuddyView(state: persona.state)
        case .gif(let installedPersona):
            GIFView(persona: installedPersona, state: persona.state)
                .frame(maxWidth: 240, maxHeight: 240)
        }
    }

    private var header: some View {
        HStack {
            Text("Claude Buddy")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            Spacer()
            connectionDot
            Button {
                showPicker = true
            } label: {
                Image(systemName: "pawprint.circle")
                    .font(.system(size: 20))
            }
            .tint(.white)
            .buttonStyle(.plain)
            .accessibilityLabel("选择宠物")
        }
    }

    private var connectionDot: some View {
        let connected: Bool = {
            if case .connected = model.connectionState { return true }
            return false
        }()
        return HStack(spacing: 6) {
            Circle()
                .fill(connected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(connected ? "connected" : "waiting")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 24) {
            stat(label: "total", value: model.snapshot.total)
            stat(label: "run", value: model.snapshot.running)
            stat(label: "wait", value: model.snapshot.waiting)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stat(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Resolution

    private enum ResolvedPersona {
        case ascii
        case gif(InstalledPersona)
    }

    private func resolvedPersona() -> ResolvedPersona {
        switch selection {
        case .asciiCat:
            return .ascii
        case .installed(let name):
            if let match = installed.first(where: { $0.name == name }) {
                return .gif(match)
            }
            return .ascii
        }
    }

    private func reloadInstalled() {
        let catalog = PersonaCatalog(rootURL: model.charactersRootURL)
        installed = catalog.listInstalled()
    }
}
