import SwiftUI

public extension Color {
    /// Initialize from an RGB565 (5-6-5 packed) value as used by TFT drivers
    /// in the `claude-desktop-buddy` firmware. Expands 5/6-bit channels to 8-bit
    /// using the standard (x << 3) | (x >> 2) scheme.
    init(rgb565: UInt16) {
        let r5 = UInt8((rgb565 >> 11) & 0x1F)
        let g6 = UInt8((rgb565 >> 5)  & 0x3F)
        let b5 = UInt8(rgb565         & 0x1F)
        let r8 = (r5 << 3) | (r5 >> 2)
        let g8 = (g6 << 2) | (g6 >> 4)
        let b8 = (b5 << 3) | (b5 >> 2)
        self.init(
            red:   Double(r8) / 255.0,
            green: Double(g8) / 255.0,
            blue:  Double(b8) / 255.0
        )
    }
}
