import SwiftUI

enum BuddyThemePreset: String, CaseIterable, Identifiable {
    case m5Orange
    case mint
    case graphite
    case coral

    var id: String { rawValue }
}

struct BuddyPalette {
    let shell: Color
    let shellShadow: Color
    let button: Color
    let screen: Color
    let highlight: Color
}

enum BuddyTheme {
    static func palette(_ raw: String) -> BuddyPalette {
        switch BuddyThemePreset(rawValue: raw) ?? .m5Orange {
        case .m5Orange:
            return BuddyPalette(
                shell: Color(red: 0.95, green: 0.44, blue: 0.20),
                shellShadow: Color(red: 0.64, green: 0.26, blue: 0.10),
                button: Color(red: 0.84, green: 0.33, blue: 0.12),
                screen: Color(red: 0.02, green: 0.03, blue: 0.04),
                highlight: Color(red: 0.98, green: 0.68, blue: 0.35)
            )
        case .mint:
            return BuddyPalette(
                shell: Color(red: 0.32, green: 0.76, blue: 0.62),
                shellShadow: Color(red: 0.18, green: 0.47, blue: 0.38),
                button: Color(red: 0.22, green: 0.60, blue: 0.47),
                screen: Color(red: 0.03, green: 0.05, blue: 0.05),
                highlight: Color(red: 0.65, green: 0.93, blue: 0.82)
            )
        case .graphite:
            return BuddyPalette(
                shell: Color(red: 0.24, green: 0.27, blue: 0.31),
                shellShadow: Color(red: 0.12, green: 0.14, blue: 0.17),
                button: Color(red: 0.18, green: 0.20, blue: 0.24),
                screen: Color(red: 0.01, green: 0.01, blue: 0.02),
                highlight: Color(red: 0.66, green: 0.76, blue: 0.88)
            )
        case .coral:
            return BuddyPalette(
                shell: Color(red: 0.93, green: 0.39, blue: 0.36),
                shellShadow: Color(red: 0.60, green: 0.20, blue: 0.19),
                button: Color(red: 0.80, green: 0.29, blue: 0.24),
                screen: Color(red: 0.04, green: 0.03, blue: 0.03),
                highlight: Color(red: 0.99, green: 0.72, blue: 0.57)
            )
        }
    }

    static func backgroundGradient(_ raw: String) -> LinearGradient {
        let palette = palette(raw)
        return LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.10, blue: 0.09),
                palette.shellShadow.opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func accentGradient(_ raw: String) -> LinearGradient {
        let palette = palette(raw)
        return LinearGradient(
            colors: [palette.highlight, palette.shell],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static let cardFill = Color.black.opacity(0.25)
    static let cardStroke = Color.white.opacity(0.12)
}

struct BuddyCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(BuddyTheme.cardFill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(BuddyTheme.cardStroke, lineWidth: 1))
    }
}
