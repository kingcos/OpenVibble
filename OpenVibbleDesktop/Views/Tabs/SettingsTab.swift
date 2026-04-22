import SwiftUI
import AppKit

struct SettingsTab: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox(label: LText("desktop.settings.language")) {
                    Picker(selection: Binding(
                        get: { l10n.language },
                        set: { l10n.set($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.titleKey, bundle: l10n.bundle).tag(lang)
                        }
                    } label: {
                        LText("desktop.settings.language")
                    }
                    .pickerStyle(.radioGroup)
                }

                GroupBox(label: LText("desktop.settings.about")) {
                    Button(action: { openWindow(id: "about") }) {
                        Label {
                            LText("desktop.about")
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
