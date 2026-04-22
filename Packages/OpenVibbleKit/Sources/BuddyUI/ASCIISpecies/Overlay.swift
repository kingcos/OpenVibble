import Foundation

public enum OverlayTint: Sendable, Equatable {
    case dim        // firmware BUDDY_DIM
    case white      // firmware BUDDY_WHITE
    case body       // follows the state's bodyColor
    case rgb565(UInt16)
}

public enum OverlayPath: Sendable, Equatable {
    /// Particle drifts up and to the right over `span` ticks, then wraps.
    case driftUpRight(speed: Double, phase: Double, span: Double)
    /// Particle orbits a center point at (0, 0) in grid units.
    case orbit(radius: Double, speed: Double, phase: Double)
    /// Stationary character at fixed grid coordinates.
    case fixed(col: Double, row: Double)
    /// Vertical bobble around a fixed center.
    case bobble(col: Double, row: Double, amp: Double, speed: Double)
    /// Escape hatch: pre-baked per-tick positions.
    case baked([BakedPoint])
}

public struct BakedPoint: Sendable, Equatable {
    public let col: Double
    public let row: Double
    public init(col: Double, row: Double) {
        self.col = col
        self.row = row
    }
}

public struct Overlay: Sendable, Equatable {
    public let char: String
    public let tint: OverlayTint
    public let path: OverlayPath

    public init(char: String, tint: OverlayTint, path: OverlayPath) {
        self.char = char
        self.tint = tint
        self.path = path
    }
}
