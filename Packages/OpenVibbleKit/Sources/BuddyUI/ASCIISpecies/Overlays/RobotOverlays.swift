import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum RobotOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .idle: idle,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
    ]

    // SLEEP: three Z-streams drift up-right over 10 ticks (low-power beeps)
    // z DIM  at (67+20+p1, 6+18 - p1*2) where p1 = t%10
    // Z CYAN at (67+26+p2, 6+14 - p2)   where p2 = (t+4)%10
    // z DIM  at (67+16+p3/2, 6+10 - p3/2) where p3 = (t+7)%10
    private static let sleep: [Overlay] = [
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 20),
                originRow: gridRow(px: 6 + 18),
                dxPerTick: 1.0 / 6.0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 10
            )
        ),
        Overlay(
            char: "Z",
            tint: .rgb565(0x07FF), // BUDDY_CYAN
            path: .linear(
                originCol: gridCol(px: 67 + 26),
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
                originCol: gridCol(px: 67 + 16),
                originRow: gridRow(px: 6 + 10),
                dxPerTick: 0.5 / 6.0,
                dyPerTick: -0.5 / 8.0,
                phase: 7,
                span: 10
            )
        ),
    ]

    // IDLE: antenna LED blink — RED "." at (67-1, BUDDY_Y_BASE-4) gated on (t/4)&1
    // BUDDY_Y_BASE=30, so pixel y = 30-4=26; gridRow(26) = (26-30)/8 = -0.5
    // period 8, active at {4,5,6,7}
    private static let idle: [Overlay] = [
        Overlay(
            char: ".",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 - 1), row: gridRow(px: 26)),
            visibility: .tickMod(period: 8, activeTicks: [4, 5, 6, 7])
        ),
    ]

    // BUSY: binary stream cycling — GREEN BITS at (67+22, 6+14)
    // BITS[] = { "1  ","10 ","101","010","10 ","1  " }; cycle t%6
    // entry 5 = "1  " same as entry 0, so we include all 6 (no blank)
    private static let busy: [Overlay] = [
        Overlay(char: "1  ", tint: .rgb565(0x07E0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [0])),
        Overlay(char: "10 ", tint: .rgb565(0x07E0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [1])),
        Overlay(char: "101", tint: .rgb565(0x07E0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [2])),
        Overlay(char: "010", tint: .rgb565(0x07E0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [3])),
        Overlay(char: "10 ", tint: .rgb565(0x07E0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [4])),
        Overlay(char: "1  ", tint: .rgb565(0x07E0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [5])),
    ]

    // ATTENTION: three flashers — YEL "!" + RED "!" + RED "*" (warning lights)
    // if (t/2) & 1:  YEL "!" at (67-6, 6)              → period 4, active at {2,3}
    // if (t/3) & 1:  RED "!" at (67+6, 6+4)             → period 6, active at {3,4,5}
    // if (t/2) & 1:  RED "*" at (67-1, BUDDY_Y_BASE-4)  → period 4, active at {2,3}
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
            char: "*",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 - 1), row: gridRow(px: 26)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
    ]

    // CELEBRATE: 6 spark/bolt streams drifting down
    // phase = (t*2 + i*11) % 22 → dyPerTick=2/8, span=22, phase offset = i*11
    // x = 67 - 36 + i*14 (fixed per stream)
    // colors cycle through YEL, CYAN, GREEN, WHITE, PURPLE
    // char alternates + vs * by stream index (firmware: (i + t/2) & 1 ? "+" : "*")
    private static let celebrate: [Overlay] = {
        let palette: [OverlayTint] = [
            .rgb565(0xFFE0), // YEL
            .rgb565(0x07FF), // CYAN
            .rgb565(0x07E0), // GREEN
            .white,
            .rgb565(0xA01F), // PURPLE
        ]
        return (0..<6).map { i in
            Overlay(
                char: i.isMultiple(of: 2) ? "+" : "*",
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

    // DIZZY: two orbiting error symbols using pre-baked 8-position table
    // OX = [0,5,7,5,0,-5,-7,-5], OY = [-5,-3,0,3,5,3,0,-3]
    // YEL "?" at (67 + OX[t%8] - 2, 6+6 + OY[t%8])
    // RED "x" at (67 + OX[(t+4)%8] - 2, 6+6 + OY[(t+4)%8])
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
            Overlay(char: "?", tint: .rgb565(0xFFE0), path: .baked(orbitPoints(startOffset: 0))),
            Overlay(char: "x", tint: .rgb565(0xF800), path: .baked(orbitPoints(startOffset: 4))),
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
