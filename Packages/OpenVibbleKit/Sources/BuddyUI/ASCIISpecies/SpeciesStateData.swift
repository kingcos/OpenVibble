import BuddyPersona

public struct SpeciesStateData: Sendable {
    public let frames: [[String]]
    public let seq: [Int]
    public let colorRGB565: UInt16
    public let overlays: [Overlay]

    public init(
        frames: [[String]],
        seq: [Int],
        colorRGB565: UInt16,
        overlays: [Overlay] = []
    ) {
        self.frames = frames
        self.seq = seq
        self.colorRGB565 = colorRGB565
        self.overlays = overlays
    }
}

// Stub — Task 7 replaces this with the full Overlay / OverlayPath / OverlayTint types.
public struct Overlay: Sendable {
    public init() {}
}
