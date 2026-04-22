import SwiftUI
import BuddyPersona

struct SpeciesPickerSheet: View {
    @Binding var selection: PersonaSpeciesID
    let builtin: [InstalledPersona]
    let installed: [InstalledPersona]
    let onClose: () -> Void

    var body: some View {
        ZStack {
            TerminalBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    TerminalPanel("species.panel.builtin") {
                        VStack(spacing: 6) {
                            asciiRowButton
                            ForEach(builtin) { persona in
                                rowButton(
                                    title: persona.manifest.name.capitalized,
                                    subtitle: statesSubtitle(persona.manifest.states.count),
                                    id: .builtin(name: persona.name)
                                )
                            }
                        }
                    }

                    TerminalPanel("species.panel.installed") {
                        if installed.isEmpty {
                            Text("species.empty.installed")
                                .font(TerminalStyle.mono(12))
                                .foregroundStyle(TerminalStyle.inkDim)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(installed) { persona in
                                    rowButton(
                                        title: persona.manifest.name,
                                        subtitle: statesSubtitle(persona.manifest.states.count),
                                        id: .installed(name: persona.name)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("species.header")
                .font(TerminalStyle.mono(16, weight: .bold))
                .foregroundStyle(TerminalStyle.ink)
            Spacer()
            Button(action: onClose) {
                Text("common.done")
            }
            .buttonStyle(TerminalHeaderButtonStyle())
        }
    }

    private func statesSubtitle(_ count: Int) -> String {
        String(format: String(localized: "species.subtitle.states"), count)
    }

    private var asciiRowButton: some View {
        Button {
            selectOrCycleASCII()
        } label: {
            rowBody(
                titleView: Text("ASCII"),
                subtitle: "ASCII \(currentASCIISpeciesLabel)",
                selected: isASCIISelection(selection)
            )
        }
        .buttonStyle(.plain)
    }

    private func rowButton(titleKey: LocalizedStringKey, subtitle: String?, id: PersonaSpeciesID) -> some View {
        Button {
            selection = id
            PersonaSelection.save(id)
        } label: {
            rowBody(titleView: Text(titleKey), subtitle: subtitle, selected: id == selection)
        }
        .buttonStyle(.plain)
    }

    private func selectOrCycleASCII() {
        if isASCIISelection(selection) {
            AsciiPetCycler.next()
            selection = PersonaSelection.load()
            return
        }
        selection = .asciiSpecies(idx: 4)
        PersonaSelection.save(selection)
    }

    private func isASCIISelection(_ id: PersonaSpeciesID) -> Bool {
        switch id {
        case .asciiCat, .asciiSpecies:
            return true
        case .builtin, .installed:
            return false
        }
    }

    private var currentASCIISpeciesLabel: String {
        switch selection {
        case .asciiCat:
            return "Cat"
        case .asciiSpecies(let idx):
            if let name = PersonaSpeciesCatalog.name(at: idx) {
                return name.capitalized
            }
            return "#\(idx)"
        case .builtin, .installed:
            return "Cat"
        }
    }

    private func rowButton(title: String, subtitle: String, id: PersonaSpeciesID) -> some View {
        Button {
            selection = id
            PersonaSelection.save(id)
        } label: {
            rowBody(titleView: Text(title), subtitle: subtitle, selected: id == selection)
        }
        .buttonStyle(.plain)
    }

    private func rowBody(titleView: Text, subtitle: String?, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                titleView
                    .font(TerminalStyle.mono(13, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(TerminalStyle.mono(10))
                        .foregroundStyle(TerminalStyle.inkDim)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TerminalStyle.ink)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            TerminalStyle.lcdPanel.opacity(selected ? 0.9 : 0.55),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    (selected ? TerminalStyle.accent : TerminalStyle.inkDim).opacity(selected ? 0.85 : 0.35),
                    lineWidth: 1
                )
        )
    }
}
