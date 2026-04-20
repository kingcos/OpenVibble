import SwiftUI

struct MainMenuSheet: View {
    let onOpenStats: () -> Void
    let onOpenInfo: () -> Void
    let onOpenPicker: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BuddyTheme.backgroundGradient.ignoresSafeArea()
                List {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenStats() }
                    } label: {
                        Label("menu.petStats", systemImage: "chart.bar.fill")
                    }
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenPicker() }
                    } label: {
                        Label("menu.changeSpecies", systemImage: "pawprint.circle")
                    }
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenInfo() }
                    } label: {
                        Label("menu.info", systemImage: "info.circle")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("menu.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}
