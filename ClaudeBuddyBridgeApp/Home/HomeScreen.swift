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
    @State private var builtin: [InstalledPersona] = PersonaCatalog.listBuiltin()
    @State private var showPicker = false
    @State private var showMenu = false
    @State private var showStats = false
    @State private var showInfo = false
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue

    var body: some View {
        ZStack {
            BuddyTheme.backgroundGradient(themePreset).ignoresSafeArea()

            VStack(spacing: 20) {
                header
                BuddyHUD(stats: stats.stats, energyTier: stats.energyTier())
                Spacer()
                M5DeviceShell {
                    buddyRenderer
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 160)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.6) { showMenu = true }
                }
                Text(persona.state.slug.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(BuddyTheme.palette(themePreset).highlight.opacity(0.85))
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
                builtin: builtin,
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
            PetStatsScreen(stats: stats, charactersRootURL: model.charactersRootURL)
                .onDisappear { reloadInstalled() }
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
            Text("app.name")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BuddyTheme.palette(themePreset).highlight)
            Spacer()
            connectionDot
            Button {
                showPicker = true
            } label: {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 22))
            }
            .tint(.white.opacity(0.9))
            .buttonStyle(.plain)
            .accessibilityLabel(Text("home.a11y.choosePet"))
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
            Text(connected ? "home.status.connected" : "home.status.waiting")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var summaryRow: some View {
        HStack(spacing: 0) {
            stat(labelKey: "home.metric.total", value: model.snapshot.total)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            stat(labelKey: "home.metric.running", value: model.snapshot.running)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            stat(labelKey: "home.metric.waiting", value: model.snapshot.waiting)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(BuddyTheme.cardFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BuddyTheme.cardStroke, lineWidth: 1))
    }

    private func stat(labelKey: LocalizedStringKey, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(labelKey)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
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
        case .builtin(let name):
            if let match = builtin.first(where: { $0.name == name }) {
                return .gif(match)
            }
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
