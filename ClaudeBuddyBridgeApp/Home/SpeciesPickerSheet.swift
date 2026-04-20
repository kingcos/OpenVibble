import SwiftUI
import BuddyPersona

struct SpeciesPickerSheet: View {
    @Binding var selection: PersonaSpeciesID
    let installed: [InstalledPersona]
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Built-in") {
                    row(title: "Cat (ASCII)", subtitle: "default fallback", id: .asciiCat)
                }

                Section("Installed") {
                    if installed.isEmpty {
                        Text("尚未安装 GIF 宠物。将 manifest 包拖入 Claude Desktop 的 Hardware Buddy 窗口即可推送。")
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
                }
            }
            .navigationTitle("选择宠物")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: onClose)
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
