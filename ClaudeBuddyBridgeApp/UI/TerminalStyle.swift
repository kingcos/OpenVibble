import SwiftUI

enum TerminalStyle {
    static let foreground = Color.green
    static let dim = Color.green.opacity(0.75)
    static let faint = Color.green.opacity(0.55)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.06, blue: 0.05),
            Color(red: 0.02, green: 0.03, blue: 0.03)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let panelFill = Color.black.opacity(0.45)
    static let panelStroke = Color.green.opacity(0.35)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct TerminalBackground: View {
    var showScanline: Bool = true

    var body: some View {
        ZStack {
            TerminalStyle.background.ignoresSafeArea()
            if showScanline {
                ScanlineOverlay()
            }
        }
    }
}

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                let width = proxy.size.width
                stride(from: 0, through: height, by: 3).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.green.opacity(0.05), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct TerminalPanel<Content: View>: View {
    let title: String?
    let accent: Color
    @ViewBuilder var content: Content

    init(_ title: String? = nil, accent: Color = .green, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text("$ \(title)")
                    .font(TerminalStyle.mono(12, weight: .semibold))
                    .foregroundStyle(accent)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TerminalStyle.panelFill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.4), lineWidth: 1)
        )
    }
}

struct TerminalHeaderButtonStyle: ButtonStyle {
    var fill: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalStyle.mono(11, weight: .semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(
                Color.black.opacity(configuration.isPressed ? 0.6 : 0.45),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
    }
}

struct TerminalActionButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalStyle.mono(12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                background.opacity(configuration.isPressed ? 0.8 : 1.0),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.black.opacity(0.35), lineWidth: 1)
            )
    }
}

struct TerminalTabBar: View {
    struct Tab: Identifiable {
        let id: String
        let label: String
        init(_ id: String, _ label: String) {
            self.id = id
            self.label = label
        }
    }

    let tabs: [Tab]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button {
                    selection = tab.id
                } label: {
                    Text(tab.label)
                        .font(TerminalStyle.mono(11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(selection == tab.id ? Color.black : Color.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selection == tab.id ? Color.green : Color.black.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
