import SwiftUI
import BuddyPersona

struct SpeciesPickerSheet: View {
    @Binding var selection: PersonaSpeciesID
    let builtin: [InstalledPersona]
    let installed: [InstalledPersona]
    let onClose: () -> Void
    @AppStorage("buddy.showScanline") private var showScanline = true

    var body: some View {
        ZStack {
            TerminalBackground(showScanline: showScanline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    TerminalPanel("species --builtin") {
                        VStack(spacing: 6) {
                            rowButton(titleKey: "species.ascii.cat", subtitle: nil, id: .asciiCat)
                            ForEach(builtin) { persona in
                                rowButton(
                                    title: persona.manifest.name.capitalized,
                                    subtitle: "\(persona.manifest.states.count) states",
                                    id: .builtin(name: persona.name)
                                )
                            }
                        }
                    }

                    TerminalPanel("species --installed") {
                        if installed.isEmpty {
                            Text("species.empty.installed")
                                .font(TerminalStyle.mono(12))
                                .foregroundStyle(.green.opacity(0.55))
                        } else {
                            VStack(spacing: 6) {
                                ForEach(installed) { persona in
                                    rowButton(
                                        title: persona.manifest.name,
                                        subtitle: "\(persona.manifest.states.count) states",
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
            Text("$ species")
                .font(TerminalStyle.mono(16, weight: .bold))
                .foregroundStyle(.green)
            Spacer()
            Button(action: onClose) {
                Text("common.done")
            }
            .buttonStyle(TerminalHeaderButtonStyle())
        }
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
                    .foregroundStyle(.green)
                if let subtitle {
                    Text(subtitle)
                        .font(TerminalStyle.mono(10))
                        .foregroundStyle(.green.opacity(0.55))
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.black.opacity(selected ? 0.55 : 0.35),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(selected ? 0.6 : 0.25), lineWidth: 1)
        )
    }
}
