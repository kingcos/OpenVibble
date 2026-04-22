// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum ChonkOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
        // .idle has no overlays per firmware
    ]

    // SLEEP: three Z-streams drift up-right over 12 ticks (lazy and heavy)
    // DIM   "z" at (67+18+p1,   BUDDY_Y_OVERLAY+20 - p1*2) p1 = t%12
    // WHITE "Z" at (67+24+p2,   BUDDY_Y_OVERLAY+16 - p2)   p2 = (t+5)%12
    // DIM   "z" at (67+30+p3/2, BUDDY_Y_OVERLAY+12 - p3/2) p3 = (t+9)%12
    private static let sleep: [Overlay] = [
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 18),
                originRow: gridRow(px: 6 + 20),
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
                originRow: gridRow(px: 6 + 16),
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
                originCol: gridCol(px: 67 + 30),
                originRow: gridRow(px: 6 + 12),
                dxPerTick: 0.5 / 6.0,
                dyPerTick: -0.5 / 8.0,
                phase: 9,
                span: 12
            )
        ),
    ]

    // BUSY: two cog spinners cycling t%4 and (t+2)%4
    // CYAN COGS[t%4]   at (67+24, BUDDY_Y_OVERLAY+12)  COGS = {"+  ","x  ","*  ","x  "}
    // WHITE COGS[(t+2)%4] at (67+30, BUDDY_Y_OVERLAY+18)
    private static let busy: [Overlay] = [
        // First cog: CYAN at x+24, y+12
        Overlay(char: "+  ", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 24), row: gridRow(px: 6 + 12)), visibility: .tickMod(period: 4, activeTicks: [0])),
        Overlay(char: "x  ", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 24), row: gridRow(px: 6 + 12)), visibility: .tickMod(period: 4, activeTicks: [1])),
        Overlay(char: "*  ", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 24), row: gridRow(px: 6 + 12)), visibility: .tickMod(period: 4, activeTicks: [2])),
        Overlay(char: "x  ", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 24), row: gridRow(px: 6 + 12)), visibility: .tickMod(period: 4, activeTicks: [3])),
        // Second cog: WHITE at x+30, y+18; offset by +2 → active ticks shift by 2
        Overlay(char: "*  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 30), row: gridRow(px: 6 + 18)), visibility: .tickMod(period: 4, activeTicks: [0])),
        Overlay(char: "x  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 30), row: gridRow(px: 6 + 18)), visibility: .tickMod(period: 4, activeTicks: [1])),
        Overlay(char: "+  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 30), row: gridRow(px: 6 + 18)), visibility: .tickMod(period: 4, activeTicks: [2])),
        Overlay(char: "x  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 30), row: gridRow(px: 6 + 18)), visibility: .tickMod(period: 4, activeTicks: [3])),
    ]

    // ATTENTION: three "!" flashers (heavy alert wobble)
    // YEL "!" at (67-6,  BUDDY_Y_OVERLAY)    period 4, active {2,3}
    // RED "!" at (67+6,  BUDDY_Y_OVERLAY+4)  period 6, active {3,4,5}
    // YEL "!" at (67-14, BUDDY_Y_OVERLAY+6)  period 8, active {4,5,6,7}
    private static let attention: [Overlay] = [
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 - 6), row: gridRow(px: 6)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 + 6), row: gridRow(px: 6 + 4)),
            visibility: .tickMod(period: 6, activeTicks: [3, 4, 5])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 - 14), row: gridRow(px: 6 + 6)),
            visibility: .tickMod(period: 8, activeTicks: [4, 5, 6, 7])
        ),
    ]

    // CELEBRATE: 7 confetti streams raining down (wider spread for chonk)
    // phase = (t*2 + i*9) % 24; x = 67-42+i*14; y = BUDDY_Y_OVERLAY-8+phase
    // cols: YEL, HEART, CYAN, WHITE, GREEN, PURPLE (6-color cycle)
    // char: (i + t/2)&1 ? "*" : "o" → static: i.isMultiple(of:2) ? "o" : "*"
    private static let celebrate: [Overlay] = {
        let palette: [OverlayTint] = [
            .rgb565(0xFFE0), // YEL
            .rgb565(0xF810), // HEART
            .rgb565(0x07FF), // CYAN
            .white,
            .rgb565(0x07E0), // GREEN
            .rgb565(0xA01F), // PURPLE
        ]
        return (0..<7).map { i in
            Overlay(
                char: i.isMultiple(of: 2) ? "o" : "*",
                tint: palette[i % 6],
                path: .linear(
                    originCol: gridCol(px: 67 - 42 + i * 14),
                    originRow: gridRow(px: 6 - 8),
                    dxPerTick: 0,
                    dyPerTick: 2.0 / 8.0,
                    phase: Double(i * 9),
                    span: 24
                )
            )
        }
    }()

    // DIZZY: three orbiting symbols in wider ellipse around chonk's big head
    // OX = [0,6,9,6,0,-6,-9,-6], OY = [-6,-4,0,4,6,4,0,-4]  (wider than standard)
    // p1=t%8, p2=(t+3)%8, p3=(t+5)%8
    // CYAN "*" at (67+OX[p1]-2, BUDDY_Y_OVERLAY+6+OY[p1])
    // YEL  "*" at (67+OX[p2]-2, BUDDY_Y_OVERLAY+6+OY[p2])
    // WHITE "+" at (67+OX[p3]-2, BUDDY_Y_OVERLAY+6+OY[p3])
    private static let dizzy: [Overlay] = {
        let OX = [0, 6, 9, 6, 0, -6, -9, -6]
        let OY = [-6, -4, 0, 4, 6, 4, 0, -4]
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
            Overlay(char: "*", tint: .rgb565(0xFFE0), path: .baked(orbitPoints(startOffset: 3))),
            Overlay(char: "+", tint: .white, path: .baked(orbitPoints(startOffset: 5))),
        ]
    }()

    // HEART: 6 heart-rise streams over 18 ticks (chonk gets extra stream)
    // phase = (t + i*3) % 18; y = BUDDY_Y_OVERLAY+16 - phase
    // x = 67-22+i*8 (jitter drop per approved rules)
    private static let heart: [Overlay] = (0..<6).map { i in
        Overlay(
            char: "v",
            tint: .rgb565(0xF810), // BUDDY_HEART
            path: .linear(
                originCol: gridCol(px: 67 - 22 + i * 8),
                originRow: gridRow(px: 6 + 16),
                dxPerTick: 0,
                dyPerTick: -1.0 / 8.0,
                phase: Double(i * 3),
                span: 18
            )
        )
    }
}
