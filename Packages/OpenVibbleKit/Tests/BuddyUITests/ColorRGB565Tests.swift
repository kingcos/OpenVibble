// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import SwiftUI
@testable import BuddyUI

@Suite("Color RGB565")
struct ColorRGB565Tests {
    @Test
    func catColorMatchesFirmware() {
        // 0xC2A6 = 11000 010101 00110 → RGB8(197, 85, 49) per 5-6-5 expansion
        let c = Color(rgb565: 0xC2A6)
        let components = c.resolve(in: .init()).cgColor.components ?? []
        #expect(abs(components[0] - 197.0/255.0) < 0.02)
        #expect(abs(components[1] - 85.0/255.0)  < 0.02)
        #expect(abs(components[2] - 49.0/255.0)  < 0.02)
    }

    @Test
    func duckColorIsYellow() {
        // 0xFFE0 = all red, all green, no blue → bright yellow
        let c = Color(rgb565: 0xFFE0)
        let components = c.resolve(in: .init()).cgColor.components ?? []
        #expect(components[0] > 0.98)
        #expect(components[1] > 0.98)
        #expect(components[2] < 0.05)
    }
}
