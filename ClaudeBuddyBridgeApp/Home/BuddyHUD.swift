import SwiftUI
import BuddyStats

struct BuddyHUD: View {
    let stats: PersonaStats
    let energyTier: UInt8

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            tile(label: "LVL", content: AnyView(levelView))
            tile(label: "FED", content: AnyView(pipBar(filled: Int(stats.fedProgress), of: 9, color: .orange)))
            tile(label: "MOOD", content: AnyView(pipBar(filled: Int(stats.moodTier), of: 4, color: .pink)))
            tile(label: "ENRG", content: AnyView(pipBar(filled: Int(energyTier), of: 5, color: .cyan)))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tile(label: String, content: AnyView) -> some View {
        VStack(spacing: 4) {
            content
                .frame(height: 14)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var levelView: some View {
        Text("\(stats.level)")
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }

    private func pipBar(filled: Int, of total: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < filled ? color : Color.white.opacity(0.15))
                    .frame(width: 6, height: 10)
            }
        }
    }
}
