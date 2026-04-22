import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum GooseOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
        // .idle has no overlays per firmware
    ]

    // SLEEP: three Z-streams drift up-right over 10 ticks (identical offsets to duck)
    // z DIM  at (67+18+p1,   6+18 - p1*2) where p1 = t%10
    // Z WHITE at (67+24+p2,   6+14 - p2)   where p2 = (t+4)%10
    // z DIM  at (67+14+p3/2, 6+10 - p3/2)  where p3 = (t+7)%10
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
                span: 10
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
                phase: 4,
                span: 10
            )
        ),
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 14),
                originRow: gridRow(px: 6 + 10),
                dxPerTick: 0.5 / 6.0,
                dyPerTick: -0.5 / 8.0,
                phase: 7,
                span: 10
            )
        ),
    ]

    // BUSY: HONKS ticker — 8 chars at fixed cursor, cycled by t%8
    // YEL at (67+22, 6+14); HONKS[t%8]
    // tick%8==7 → blank "   ", no overlay needed
    private static let busy: [Overlay] = [
        Overlay(char: "h  ", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [0])),
        Overlay(char: "ho ", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [1])),
        Overlay(char: "hon", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [2])),
        Overlay(char: "onk", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [3])),
        Overlay(char: "nk!", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [4])),
        Overlay(char: "k! ", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [5])),
        Overlay(char: "!  ", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 8, activeTicks: [6])),
    ]

    // ATTENTION: three "!" flashers at fixed positions
    // if (t/2) & 1:  RED "!" at (67-6,  6)     → period 4, active at {2,3}
    // if (t/3) & 1:  YEL "!" at (67+6,  6+4)   → period 6, active at {3,4,5}
    // if (t/4) & 1:  RED "!" at (67+14, 6+8)   → period 8, active at {4,5,6,7}
    private static let attention: [Overlay] = [
        Overlay(
            char: "!",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 - 6), row: gridRow(px: 6)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 + 6), row: gridRow(px: 6 + 4)),
            visibility: .tickMod(period: 6, activeTicks: [3, 4, 5])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 + 14), row: gridRow(px: 6 + 8)),
            visibility: .tickMod(period: 8, activeTicks: [4, 5, 6, 7])
        ),
    ]

    // CELEBRATE: 7 confetti streams drifting down
    // phase = (t*2 + i*9) % 22 → dyPerTick=2/8, span=22, phase offset = i*9
    // x = 67 - 40 + i*12 (fixed per stream)
    // colors cycle through YEL, HEART, CYAN, WHITE, GREEN
    // char alternates * vs o by stream index (firmware: (i + t/2) & 1 ? "*" : "o")
    private static let celebrate: [Overlay] = {
        let palette: [OverlayTint] = [
            .rgb565(0xFFE0), // YEL
            .rgb565(0xF810), // HEART
            .rgb565(0x07FF), // CYAN
            .white,
            .rgb565(0x07E0), // GREEN
        ]
        return (0..<7).map { i in
            Overlay(
                char: i.isMultiple(of: 2) ? "*" : "o",
                tint: palette[i % 5],
                path: .linear(
                    originCol: gridCol(px: 67 - 40 + i * 12),
                    originRow: gridRow(px: 0),
                    dxPerTick: 0,
                    dyPerTick: 2.0 / 8.0,
                    phase: Double(i * 9),
                    span: 22
                )
            )
        }
    }()

    // DIZZY: three orbiting stars using pre-baked 8-position table
    // OX = [0,5,7,5,0,-5,-7,-5], OY = [-5,-3,0,3,5,3,0,-3]
    // CYAN "*" at offset 0, YEL "*" at offset 4, PURPLE "+" at offset 2
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
            Overlay(char: "+", tint: .rgb565(0xA01F), path: .baked(orbitPoints(startOffset: 2))), // BUDDY_PURPLE
        ]
    }()

    // HEART: 5 heart-rise streams over 16 ticks
    // phase = (t + i*4) % 16; y = 6 + 16 - phase (rises as phase increases)
    // x = 67 - 20 + i*8 (jitter simplified away)
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
