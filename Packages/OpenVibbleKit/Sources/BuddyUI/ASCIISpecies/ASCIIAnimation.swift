// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct ASCIIFrame: Sendable, Equatable {
    public let lines: [String]
    public init(_ lines: [String]) { self.lines = lines }
}

public struct ASCIIAnimation: Sendable {
    public let poses: [ASCIIFrame]
    public let sequence: [Int]
    public let ticksPerBeat: Int
    public init(poses: [ASCIIFrame], sequence: [Int], ticksPerBeat: Int) {
        self.poses = poses
        self.sequence = sequence
        self.ticksPerBeat = ticksPerBeat
    }
    public func frame(at tick: Int) -> ASCIIFrame {
        let beat = (tick / ticksPerBeat) % sequence.count
        return poses[sequence[beat]]
    }
}
