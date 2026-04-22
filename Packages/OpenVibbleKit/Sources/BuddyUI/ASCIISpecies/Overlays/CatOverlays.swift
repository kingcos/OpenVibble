// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum CatOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
        // .idle has no overlays per firmware
    ]

    // SLEEP: three Z-streams drift up-right over 12 ticks
    // z DIM  at (67+18+p1,   6+18 - p1*2) where p1 = t%12
    // Z WHITE at (67+24+p2,   6+14 - p2)   where p2 = (t+5)%12
    // z DIM  at (67+14+p3/2, 6+8  - p3/2)  where p3 = (t+9)%12
    private static let sleep: [Overlay] = [
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 18),
                originRow: gridRow(px: 6 + 18),
                dxPerTick: 1.0 / 6.0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 12
            )
        ),
        Overlay(
            char: "Z",
            tint: .white,
            path: .linear(
                originCol: gridCol(px: 67 + 24),
                originRow: gridRow(px: 6 + 14),
                dxPerTick: 1.0 / 6.0,
                dyPerTick: -1.0 / 8.0,
                phase: 5,
                span: 12
            )
        ),
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 14),
                originRow: gridRow(px: 6 + 8),
                dxPerTick: 0.5 / 6.0,
                dyPerTick: -0.5 / 8.0,
                phase: 9,
                span: 12
            )
        ),
    ]

    // BUSY: DOTS ticker — 6 chars at fixed cursor, cycled by t%6
    // WHITE at (67+22, 6+14); print DOTS[t % 6]
    // tick%6==5 → blank "   ", no overlay needed
    private static let busy: [Overlay] = [
        Overlay(char: ".  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [0])),
        Overlay(char: ".. ", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [1])),
        Overlay(char: "...", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [2])),
        Overlay(char: " ..", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [3])),
        Overlay(char: "  .", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [4])),
    ]

    // ATTENTION: two "!" flashers at fixed positions
    // if (t/2) & 1:  YEL "!" at (67-4, 6)     → period 4, active at {2,3}
    // if (t/3) & 1:  YEL "!" at (67+4, 6+4)   → period 6, active at {3,4,5}
    private static let attention: [Overlay] = [
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 - 4), row: gridRow(px: 6)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 + 4), row: gridRow(px: 6 + 4)),
            visibility: .tickMod(period: 6, activeTicks: [3, 4, 5])
        ),
    ]

    // CELEBRATE: 6 confetti streams drifting down
    // phase = (t*2 + i*11) % 22 → dyPerTick=2/8, span=22, phase offset = i*11
    // x = 67 - 36 + i*14 (fixed per stream)
    // colors cycle through YEL, HEART, CYAN, WHITE, GREEN
    // char alternates * vs . by stream index
    private static let celebrate: [Overlay] = {
        let palette: [OverlayTint] = [
            .rgb565(0xFFE0), // YEL
            .rgb565(0xF810), // HEART
            .rgb565(0x07FF), // CYAN
            .white,
            .rgb565(0x07E0), // GREEN
        ]
        return (0..<6).map { i in
            Overlay(
                char: i.isMultiple(of: 2) ? "*" : ".",
                tint: palette[i % 5],
                path: .linear(
                    originCol: gridCol(px: 67 - 36 + i * 14),
                    originRow: gridRow(px: 0),
                    dxPerTick: 0,
                    dyPerTick: 2.0 / 8.0,
                    phase: Double(i * 11),
                    span: 22
                )
            )
        }
    }()

    // DIZZY: two orbiting "*" stars using pre-baked 8-position table
    // OX = [0,5,7,5,0,-5,-7,-5], OY = [-5,-3,0,3,5,3,0,-3]
    // CYAN "*" at (67 + OX[t%8] - 2, 6+6 + OY[t%8])
    // YEL  "*" at (67 + OX[(t+4)%8] - 2, 6+6 + OY[(t+4)%8])
    private static let dizzy: [Overlay] = {
        let OX = [0, 5, 7, 5, 0, -5, -7, -5]
        let OY = [-5, -3, 0, 3, 5, 3, 0, -3]
        func orbitPoints(startOffset: Int) -> [BakedPoint] {
            (0..<8).map { i in
                let idx = (i + startOffset) % 8
                return BakedPoint(
                    col: gridCol(px: 67 + OX[idx] - 2),
                    row: gridRow(px: 6 + 6 + OY[idx])
                )
            }
        }
        return [
            Overlay(char: "*", tint: .rgb565(0x07FF), path: .baked(orbitPoints(startOffset: 0))),
            Overlay(char: "*", tint: .rgb565(0xFFE0), path: .baked(orbitPoints(startOffset: 4))),
        ]
    }()

    // HEART: 5 heart-rise streams over 16 ticks
    // phase = (t + i*4) % 16; y = 6 + 16 - phase (rises as phase increases)
    // x = 67 - 20 + i*8 (jitter simplified away)
    // linear: originRow = gridRow(6+16), dyPerTick = -1/8, span=16, phase=i*4
    private static let heart: [Overlay] = (0..<5).map { i in
        Overlay(
            char: "v",
            tint: .rgb565(0xF810), // BUDDY_HEART
            path: .linear(
                originCol: gridCol(px: 67 - 20 + i * 8),
                originRow: gridRow(px: 6 + 16),
                dxPerTick: 0,
                dyPerTick: -1.0 / 8.0,
                phase: Double(i * 4),
                span: 16
            )
        )
    }
}
