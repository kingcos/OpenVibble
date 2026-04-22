// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import BuddyUI

@Suite("OverlayRenderer")
struct OverlayRendererTests {
    @Test
    func fixedPathReturnsConstant() {
        let path = OverlayPath.fixed(col: 3, row: 2)
        let p0 = OverlayRenderer.position(for: path, tick: 0)
        let p10 = OverlayRenderer.position(for: path, tick: 10)
        #expect(p0.col == 3 && p0.row == 2)
        #expect(p10.col == 3 && p10.row == 2)
    }

    @Test
    func driftUpRightWrapsAtSpan() {
        let path = OverlayPath.driftUpRight(speed: 1.0, phase: 0, span: 12)
        let p0 = OverlayRenderer.position(for: path, tick: 0)
        let p12 = OverlayRenderer.position(for: path, tick: 12)
        #expect(abs(p0.col - p12.col) < 0.001)
        #expect(abs(p0.row - p12.row) < 0.001)
    }

    @Test
    func bakedCyclesThroughPoints() {
        let points = [
            BakedPoint(col: 0, row: 0),
            BakedPoint(col: 1, row: 1),
            BakedPoint(col: 2, row: 2),
        ]
        let path = OverlayPath.baked(points)
        let p0 = OverlayRenderer.position(for: path, tick: 0)
        let p3 = OverlayRenderer.position(for: path, tick: 3)
        let p4 = OverlayRenderer.position(for: path, tick: 4)
        #expect(p0.col == 0 && p0.row == 0)
        #expect(p3.col == 0 && p3.row == 0)
        #expect(p4.col == 1 && p4.row == 1)
    }
}
