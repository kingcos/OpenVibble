import SwiftUI

/// Widget-safe subset of `TerminalStyle` (no UIKit dependency, no scanline overlay).
/// Mirrors the palette used by the main app so the Live Activity reads as the same
/// LCD/terminal surface.
enum TerminalStyleLite {
    static let ink       = Color(red: 0.804, green: 0.910, blue: 0.808)   // #cde8ce
    static let inkDim    = Color(red: 0.435, green: 0.522, blue: 0.443)   // #6f8571
    static let lcdBg     = Color(red: 0.059, green: 0.063, blue: 0.063)   // #0f1010
    static let lcdPanel  = Color(red: 0.129, green: 0.133, blue: 0.133)
    static let good      = Color(red: 0.086, green: 0.557, blue: 0.341)   // #168e57
    static let accent    = Color(red: 0.918, green: 0.353, blue: 0.165)   // #ea5a2a
    static let bad       = Color(red: 0.816, green: 0.220, blue: 0.196)   // #d03832

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
