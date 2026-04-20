import SwiftUI

struct M5DeviceShell<Content: View>: View {
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue
    @ViewBuilder var content: Content

    var body: some View {
        let palette = BuddyTheme.palette(themePreset)
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.screen)
                .overlay(content.padding(12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(height: 260)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.button)
                .frame(width: 116, height: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: palette.shellShadow.opacity(0.45), radius: 8, y: 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(palette.shell)
        )
        .shadow(color: palette.shellShadow.opacity(0.35), radius: 12, y: 10)
    }
}
