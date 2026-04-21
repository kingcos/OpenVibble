import SwiftUI

// Palette lifted from `h5-demo.html` so the iOS UI matches the H5 dev-board
// replica of the M5 handheld: salmon-red shell, dark LCD, mint-green ink,
// orange/salmon warning accents, colored mood/energy indicators.
enum TerminalStyle {
    // LCD inks ---------------------------------------------------------------
    static let ink       = Color(red: 0.804, green: 0.910, blue: 0.808)   // #cde8ce
    static let inkDim    = Color(red: 0.435, green: 0.522, blue: 0.443)   // #6f8571
    static let inkFaint  = Color(red: 0.435, green: 0.522, blue: 0.443).opacity(0.6)

    // Legacy aliases (kept so existing `.foreground/.dim/.faint` call-sites stay green-mint)
    static let foreground = ink
    static let dim        = inkDim
    static let faint      = inkFaint

    // LCD backgrounds --------------------------------------------------------
    static let lcdBg      = Color(red: 0.059, green: 0.063, blue: 0.063)  // #0f1010
    static let lcdBgHi    = Color(red: 0.102, green: 0.106, blue: 0.106)
    static let lcdPanel   = Color(red: 0.129, green: 0.133, blue: 0.133)
    static let lcdDivider = Color(red: 0.180, green: 0.184, blue: 0.180)  // #2e2f2e

    // Warm accents (match h5 demo `--accent`, `--accent-2`, `--bad`) ---------
    static let accent     = Color(red: 0.918, green: 0.353, blue: 0.165)  // #ea5a2a
    static let accentSoft = Color(red: 1.000, green: 0.702, blue: 0.365)  // #ffb35d
    static let bad        = Color(red: 0.816, green: 0.220, blue: 0.196)  // #d03832
    static let good       = Color(red: 0.086, green: 0.557, blue: 0.341)  // #168e57

    // Mood heart tiers -------------------------------------------------------
    static let moodHot    = Color(red: 0.945, green: 0.353, blue: 0.314)  // #f15a50
    static let moodWarm   = Color(red: 0.941, green: 0.639, blue: 0.310)  // #f0a34f
    static let moodDim    = Color(red: 0.561, green: 0.596, blue: 0.557)  // #8f988e

    // Energy bar tiers -------------------------------------------------------
    static let enHigh     = Color(red: 0.420, green: 0.847, blue: 0.953)  // #6bd8f3
    static let enMid      = Color(red: 0.910, green: 0.898, blue: 0.420)  // #e8e56b
    static let enLow      = Color(red: 0.937, green: 0.416, blue: 0.314)  // #ef6a50

    // Pink/salmon Lv badge ---------------------------------------------------
    static let levelBg    = Color(red: 0.918, green: 0.776, blue: 0.718)  // #eac6b7
    static let levelInk   = Color(red: 0.125, green: 0.122, blue: 0.114)  // #201f1d

    // Device shell colors (the red/orange body around the LCD) ---------------
    static let shellTop      = Color(red: 1.000, green: 0.553, blue: 0.341)  // #ff8d57
    static let shellMid      = Color(red: 0.918, green: 0.353, blue: 0.165)  // #ea5a2a
    static let shellBottom   = Color(red: 0.859, green: 0.259, blue: 0.082)  // #db4215
    static let shellEdge     = Color(red: 0.098, green: 0.098, blue: 0.090)  // #191917
    static let shellHighlight = Color.white.opacity(0.12)
    static let shellShadow   = Color(red: 0.706, green: 0.259, blue: 0.094).opacity(0.55)

    static let background = LinearGradient(
        colors: [lcdBg, Color.black],
        startPoint: .top,
        endPoint: .bottom
    )

    static let panelFill   = lcdBgHi.opacity(0.72)
    static let panelStroke = inkDim.opacity(0.45)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Display font for big titles — mimics h5-demo's "Chakra Petch":
    /// bold + condensed width SF Pro so headline text feels angular and dense.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default).width(.condensed)
    }
}

// MARK: - Background

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
            .stroke(TerminalStyle.ink.opacity(0.05), lineWidth: 0.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Device shell (the orange/red M5-style body wrapping the LCD)

struct DeviceShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                // Outer body: rounded orange gradient like the h5 `.device`.
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TerminalStyle.shellTop,
                                TerminalStyle.shellMid,
                                TerminalStyle.shellBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(TerminalStyle.shellEdge, lineWidth: 3)
                    )
                    .overlay(alignment: .top) {
                        // Subtle highlight at the top of the shell.
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(TerminalStyle.shellHighlight)
                            .frame(height: max(8, h * 0.06))
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                            .blur(radius: 6)
                    }
                    .overlay(alignment: .bottom) {
                        // Embossed "M5" style badge at the bottom of the shell.
                        Text("M5")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(TerminalStyle.shellBottom.opacity(0.85))
                            .shadow(color: .white.opacity(0.18), radius: 0, x: 0, y: 1)
                            .padding(.bottom, max(14, h * 0.035))
                    }
                    .shadow(color: TerminalStyle.shellShadow, radius: 14, x: 0, y: 12)

                // Side rocker button on the right edge, echoing h5's `.btn-b`.
                Capsule()
                    .fill(TerminalStyle.shellBottom)
                    .frame(width: 5, height: 42)
                    .overlay(Capsule().stroke(TerminalStyle.shellEdge, lineWidth: 1.5))
                    .offset(x: w / 2 - 1, y: -h * 0.18)

                // LCD inset: positioned in the upper ~80% of the shell.
                VStack(spacing: 0) {
                    LCDFrame { content }
                        .padding(.top, max(18, h * 0.03))
                        .padding(.horizontal, max(18, w * 0.05))
                    Spacer(minLength: max(60, h * 0.10))
                }
            }
        }
    }
}

/// Dark LCD pane — black fill, thin dark border, mint-green ink inside.
struct LCDFrame<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(TerminalStyle.lcdBg)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Panel

struct TerminalPanel<Content: View>: View {
    let title: LocalizedStringKey?
    let accent: Color
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey? = nil, accent: Color = TerminalStyle.ink, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(spacing: 0) {
                    Text(verbatim: "$ ")
                    Text(title)
                }
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

// MARK: - Buttons

struct TerminalHeaderButtonStyle: ButtonStyle {
    var fill: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalStyle.mono(11, weight: .semibold))
            .foregroundStyle(TerminalStyle.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(
                TerminalStyle.lcdPanel.opacity(configuration.isPressed ? 0.9 : 0.7),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TerminalStyle.inkDim.opacity(0.55), lineWidth: 1)
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

// MARK: - Tab bar

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
                        .foregroundStyle(selection == tab.id ? TerminalStyle.lcdBg : TerminalStyle.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selection == tab.id ? TerminalStyle.ink : TerminalStyle.lcdPanel.opacity(0.7),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(TerminalStyle.inkDim.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Pet-view primitives (match h5 `pet-view` indicators)

enum PetIndicator {
    /// 4 hearts; filled tier drives color: >=3 hot, >=2 warm, else dim.
    struct MoodRow: View {
        let tier: Int

        var body: some View {
            let color: Color = tier >= 3 ? TerminalStyle.moodHot
                             : tier >= 2 ? TerminalStyle.moodWarm
                             : TerminalStyle.moodDim
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Text(i < tier ? "♥" : "♡")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(i < tier ? color : TerminalStyle.moodDim)
                }
            }
        }
    }

    struct FedRow: View {
        let filled: Int   // 0...10

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { i in
                    let on = i < filled
                    Circle()
                        .fill(on ? TerminalStyle.ink : Color.clear)
                        .overlay(
                            Circle().stroke(on ? TerminalStyle.ink : TerminalStyle.inkDim, lineWidth: 1)
                        )
                        .frame(width: 7, height: 7)
                }
            }
        }
    }

    struct EnergyRow: View {
        let tier: Int     // 0...5

        var body: some View {
            let color: Color = tier >= 4 ? TerminalStyle.enHigh
                             : tier >= 2 ? TerminalStyle.enMid
                             : TerminalStyle.enLow
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    let on = i < tier
                    Rectangle()
                        .fill(on ? color : Color.clear)
                        .frame(width: 11, height: 8)
                        .overlay(
                            Rectangle().stroke(on ? color : TerminalStyle.inkDim, lineWidth: 1)
                        )
                }
            }
        }
    }

    struct LevelBadge: View {
        let level: UInt8

        var body: some View {
            Text("Lv \(level)")
                .font(TerminalStyle.mono(12, weight: .bold))
                .foregroundStyle(TerminalStyle.levelInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(TerminalStyle.levelBg, in: RoundedRectangle(cornerRadius: 5))
        }
    }
}
