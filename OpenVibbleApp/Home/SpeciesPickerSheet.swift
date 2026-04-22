// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import BuddyPersona
import BuddyUI

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

                    TerminalPanel("species.panel.preview") {
                        previewSpeciesView
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                    }

                    TerminalPanel(
                        "species.panel.builtin",
                        collapsible: true,
                        collapsedByDefault: true
                    ) {
                        VStack(spacing: 6) {
                            ForEach(Array(PersonaSpeciesCatalog.names.enumerated()), id: \.offset) { idx, name in
                                rowButton(
                                    title: "ASCII (\(name.capitalized))",
                                    subtitle: idx == 4 ? "默认形态" : "idx \(idx)",
                                    id: asciiID(for: idx)
                                )
                            }
                            ForEach(builtin) { persona in
                                rowButton(
                                    title: persona.manifest.name.capitalized,
                                    subtitle: statesSubtitle(persona.manifest.states.count),
                                    id: .builtin(name: persona.name)
                                )
                            }
                        }
                    }

                    TerminalPanel(
                        "species.panel.installed",
                        collapsible: true,
                        collapsedByDefault: true
                    ) {
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

    @ViewBuilder
    private var previewSpeciesView: some View {
        switch selection {
        case .asciiCat:
            ASCIIBuddyView(state: .idle)
                .scaleEffect(0.72)
        case .asciiSpecies(let idx):
            ASCIIBuddyView(state: .idle, speciesIdx: idx)
                .scaleEffect(0.72)
        case .builtin(let name):
            if let persona = builtin.first(where: { $0.name == name }) {
                GIFView(persona: persona, state: .idle)
                    .aspectRatio(contentMode: .fit)
            } else {
                ASCIIBuddyView(state: .idle)
                    .scaleEffect(0.72)
            }
        case .installed(let name):
            if let persona = installed.first(where: { $0.name == name }) {
                GIFView(persona: persona, state: .idle)
                    .aspectRatio(contentMode: .fit)
            } else {
                ASCIIBuddyView(state: .idle)
                    .scaleEffect(0.72)
            }
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

    private func asciiID(for idx: Int) -> PersonaSpeciesID {
        idx == 4 ? .asciiCat : .asciiSpecies(idx: idx)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
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
