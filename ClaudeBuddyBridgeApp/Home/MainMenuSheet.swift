import SwiftUI

struct MainMenuSheet: View {
    let onOpenStats: () -> Void
    let onOpenInfo: () -> Void
    let onOpenPicker: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenStats() }
                } label: {
                    Label("Pet Stats", systemImage: "chart.bar.fill")
                }
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenPicker() }
                } label: {
                    Label("Change Species", systemImage: "pawprint.circle")
                }
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenInfo() }
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
            }
            .navigationTitle("Menu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
