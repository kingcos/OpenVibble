import SwiftUI

enum RootPage: String, CaseIterable, Identifiable {
    case pet
    case terminal

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pet: return "pawprint.fill"
        case .terminal: return "terminal.fill"
        }
    }

    var label: String {
        switch self {
        case .pet: return "PET"
        case .terminal: return "TERM"
        }
    }
}

struct MechanicalSwitch: View {
    @Binding var page: RootPage

    private let thumbWidth: CGFloat = 72
    private let trackHeight: CGFloat = 48
    private let padding: CGFloat = 4
    private let thumb = Color.green
    private let thumbShadow = Color(red: 0.05, green: 0.35, blue: 0.15)

    var body: some View {
        HStack(spacing: 0) {
            half(.pet)
            half(.terminal)
        }
        .frame(width: thumbWidth * 2 + padding * 2, height: trackHeight)
        .background(
            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: (trackHeight - padding * 2) / 2, style: .continuous)
                .fill(thumb)
                .overlay(
                    RoundedRectangle(cornerRadius: (trackHeight - padding * 2) / 2, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: thumbShadow.opacity(0.6), radius: 6, y: 3)
                .padding(padding)
                .frame(width: thumbWidth + padding * 2)
                .offset(x: page == .pet ? 0 : thumbWidth)
                .allowsHitTesting(false)
        }
        .animation(.interpolatingSpring(stiffness: 260, damping: 22), value: page)
        .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)
    }

    private func half(_ target: RootPage) -> some View {
        let selected = page == target
        return Button {
            if page != target { page = target }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: target.icon)
                    .font(.system(size: 15, weight: .bold))
                Text(target.label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(selected ? Color.black : Color.green.opacity(0.7))
            .frame(width: thumbWidth, height: trackHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(target.label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
