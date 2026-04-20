import SwiftUI

enum BuddyTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.07, blue: 0.12),
            Color(red: 0.02, green: 0.03, blue: 0.06)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.32, green: 0.62, blue: 1.0), Color(red: 0.6, green: 0.35, blue: 1.0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardFill = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.08)
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
