import SwiftUI
import BuddyPersona

struct SpeciesPickerSheet: View {
    @Binding var selection: PersonaSpeciesID
    let installed: [InstalledPersona]
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                BuddyTheme.backgroundGradient.ignoresSafeArea()
                List {
                    Section {
                        row(titleKey: "species.ascii.cat", subtitleKey: nil, id: .asciiCat)
                    } header: {
                        Text("species.builtin")
                    }

                    Section {
                        if installed.isEmpty {
                            Text("species.empty.installed")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(installed) { persona in
                                row(
                                    title: persona.manifest.name,
                                    subtitle: "\(persona.manifest.states.count) states",
                                    id: .installed(name: persona.name)
                                )
                            }
                        }
                    } header: {
                        Text("species.installed")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("species.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done", action: onClose)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(titleKey: LocalizedStringKey, subtitleKey: LocalizedStringKey?, id: PersonaSpeciesID) -> some View {
        Button {
            selection = id
            PersonaSelection.save(id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey).foregroundStyle(.primary)
                    if let subtitleKey {
                        Text(subtitleKey).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if id == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func row(title: String, subtitle: String, id: PersonaSpeciesID) -> some View {
        Button {
            selection = id
            PersonaSelection.save(id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if id == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }
}
