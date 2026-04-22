// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

