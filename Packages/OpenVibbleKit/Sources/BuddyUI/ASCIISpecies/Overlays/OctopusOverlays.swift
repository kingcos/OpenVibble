import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum OctopusOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
        // .idle has no overlays per firmware
    ]

    // SLEEP: three Z-streams drift up over 10 ticks
    // DIM   "z" at (67+18+p1,   BUDDY_Y_OVERLAY+16 - p1*2) p1 = t%10
    // WHITE "Z" at (67+24+p2,   BUDDY_Y_OVERLAY+12 - p2)   p2 = (t+4)%10
    // DIM   "z" at (67+14+p3/2, BUDDY_Y_OVERLAY+8  - p3/2) p3 = (t+7)%10
    private static let sleep: [Overlay] = [
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 18),
                originRow: gridRow(px: 6 + 16),
                dxPerTick: 1.0 / 6.0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 10
            )
        ),
        Overlay(
            char: "Z",
            tint: .white,
            path: .linear(
                originCol: gridCol(px: 67 + 24),
                originRow: gridRow(px: 6 + 12),
                dxPerTick: 1.0 / 6.0,
                dyPerTick: -1.0 / 8.0,
                phase: 4,
                span: 10
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
                phase: 7,
                span: 10
            )
        ),
    ]

    // BUSY: DOTS ticker at (67+22, BUDDY_Y_OVERLAY+14) CYAN, t%6
    // + tiny bubble: WHITE "o" at (67-30, BUDDY_Y_OVERLAY+18-b), b=(t*2)%18
    //   b advances 2 per tick → span=9 ticks
    //   NOTE: x = BUDDY_X_CENTER - 30, which is far left of sprite
    private static let busy: [Overlay] = [
        Overlay(char: ".  ", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [0])),
        Overlay(char: ".. ", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [1])),
        Overlay(char: "...", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [2])),
        Overlay(char: " ..", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [3])),
        Overlay(char: "  .", tint: .rgb565(0x07FF), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [4])),
        // tiny bubble far left: b=(t*2)%18, dy = -2/8 per tick, span=9
        Overlay(
            char: "o",
            tint: .white,
            path: .linear(
                originCol: gridCol(px: 67 - 30),
                originRow: gridRow(px: 6 + 18),
                dxPerTick: 0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 9
            )
        ),
    ]

    // ATTENTION: two YEL "!" flashers (both yellow — octopus uses YEL for both)
    // YEL "!" at (67-6, BUDDY_Y_OVERLAY)     period 4, active {2,3}
    // YEL "!" at (67+6, BUDDY_Y_OVERLAY+4)   period 6, active {3,4,5}
    private static let attention: [Overlay] = [
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 - 6), row: gridRow(px: 6)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 + 6), row: gridRow(px: 6 + 4)),
            visibility: .tickMod(period: 6, activeTicks: [3, 4, 5])
        ),
    ]

    // CELEBRATE: 6 confetti streams raining down
    // phase = (t*2 + i*11) % 22; x = 67-36+i*14
    // cols: YEL, HEART, CYAN, WHITE, GREEN (5-color)
    // char: (i + t/2)&1 ? "*" : "o" → static: i.isMultiple(of:2) ? "o" : "*"
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
                char: i.isMultiple(of: 2) ? "o" : "*",
                tint: palette[i % 5],
                path: .linear(
                    originCol: gridCol(px: 67 - 36 + i * 14),
                    originRow: gridRow(px: 6 - 6),
                    dxPerTick: 0,
                    dyPerTick: 2.0 / 8.0,
                    phase: Double(i * 11),
                    span: 22
                )
            )
        }
    }()

    // DIZZY: two orbiting stars + ink cloud puffs gated on (t/8)&1
    // OX = [0,5,7,5,0,-5,-7,-5], OY = [-5,-3,0,3,5,3,0,-3]
    // p1=t%8, p2=(t+4)%8
    // CYAN "*" at (67+OX[p1]-2, BUDDY_Y_OVERLAY+4+OY[p1])
    // PURPLE "*" at (67+OX[p2]-2, BUDDY_Y_OVERLAY+4+OY[p2])
    // NOTE: y base is BUDDY_Y_OVERLAY+4 (not +6 like others)
    // Ink cloud: DIM "o" at (67-24-puff, BUDDY_Y_OVERLAY+10+puff) and (67+24+puff, BUDDY_Y_OVERLAY+10+puff)
    //   puff = t%8, gated (t/8)&1 → period=16, active {8..15}
    //   x drifts left/right, y drifts down by 1 per tick; puff advances 1/tick
    private static let dizzy: [Overlay] = {
        let OX = [0, 5, 7, 5, 0, -5, -7, -5]
        let OY = [-5, -3, 0, 3, 5, 3, 0, -3]
        func orbitPoints(startOffset: Int) -> [BakedPoint] {
            (0..<8).map { i in
                let idx = (i + startOffset) % 8
                return BakedPoint(
                    col: gridCol(px: 67 + OX[idx] - 2),
                    row: gridRow(px: 6 + 4 + OY[idx])  // BUDDY_Y_OVERLAY+4
                )
            }
        }
        // Ink cloud baked points: puff = 0..7, drifts diagonally
        // Left cloud: x = 67-24-puff, y = BUDDY_Y_OVERLAY+10+puff
        let leftInkPoints: [BakedPoint] = (0..<8).map { puff in
            BakedPoint(
                col: gridCol(px: 67 - 24 - puff),
                row: gridRow(px: 6 + 10 + puff)
            )
        }
        // Right cloud: x = 67+24+puff, y = BUDDY_Y_OVERLAY+10+puff
        let rightInkPoints: [BakedPoint] = (0..<8).map { puff in
            BakedPoint(
                col: gridCol(px: 67 + 24 + puff),
                row: gridRow(px: 6 + 10 + puff)
            )
        }
        return [
            Overlay(char: "*", tint: .rgb565(0x07FF), path: .baked(orbitPoints(startOffset: 0))),
            Overlay(char: "*", tint: .rgb565(0xA01F), path: .baked(orbitPoints(startOffset: 4))),
            // Ink clouds: gated (t/8)&1 → period=16, active {8..15}; baked follows puff = t%8
            Overlay(
                char: "o",
                tint: .dim,
                path: .baked(leftInkPoints),
                visibility: .tickMod(period: 16, activeTicks: Array(8..<16))
            ),
            Overlay(
                char: "o",
                tint: .dim,
                path: .baked(rightInkPoints),
                visibility: .tickMod(period: 16, activeTicks: Array(8..<16))
            ),
        ]
    }()

    // HEART: 5 heart-rise streams over 16 ticks (jitter drop per approved rules)
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
