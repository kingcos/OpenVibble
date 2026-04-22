import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum AxolotlOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .idle: idle,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
    ]

    // SLEEP: two bubble streams + one z drift up-right over 12 ticks
    // CYAN "o" at (67+18+(p1%3),  BUDDY_Y_OVERLAY+20 - p1*2) p1 = t%12
    // WHITE "O" at (67+26-(p2%4), BUDDY_Y_OVERLAY+18 - p2)   p2 = (t+5)%12
    // DIM   "z" at (67+14+(p3%5), BUDDY_Y_OVERLAY+12 - p3/2) p3 = (t+9)%12
    // The %3/%4/%5 jitter is baked as startOffset=0 approximation (drop jitter per approved rules)
    private static let sleep: [Overlay] = [
        Overlay(
            char: "o",
            tint: .rgb565(0x07FF), // BUDDY_CYAN
            path: .linear(
                originCol: gridCol(px: 67 + 18),
                originRow: gridRow(px: 6 + 20),
                dxPerTick: 0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 12
            )
        ),
        Overlay(
            char: "O",
            tint: .white,
            path: .linear(
                originCol: gridCol(px: 67 + 26),
                originRow: gridRow(px: 6 + 18),
                dxPerTick: 0,
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
                originRow: gridRow(px: 6 + 12),
                dxPerTick: 0,
                dyPerTick: -0.5 / 8.0,
                phase: 9,
                span: 12
            )
        ),
    ]

    // IDLE: single lazy bubble drifting up, alternates o/O by (p&1)
    // CYAN at (67+24, BUDDY_Y_OVERLAY+16 - p), p = (t/2)%14
    // Static char alternation (i.isMultiple) → use "o" for even ticks, "O" for odd
    // Modeled as two overlays with tickMod, each period=2 speed (p advances every 2 ticks)
    // Simpler: one overlay drifting up span=28 (14 ticks * 2 step), use "o" static (approved drop of alternation)
    private static let idle: [Overlay] = [
        Overlay(
            char: "o",
            tint: .rgb565(0x07FF), // BUDDY_CYAN
            path: .linear(
                originCol: gridCol(px: 67 + 24),
                originRow: gridRow(px: 6 + 16),
                dxPerTick: 0,
                dyPerTick: -1.0 / 8.0,
                phase: 0,
                span: 14
            )
        ),
    ]

    // BUSY: DOTS ticker at (67+22, BUDDY_Y_OVERLAY+14) WHITE, t%6
    // + tiny bubble: CYAN "o" at (67-28, BUDDY_Y_OVERLAY+18 - b), b = (t*2)%10, drifts up
    // dot ticker: period=6, entries 0-4 (entry 5 is blank, skip)
    private static let busy: [Overlay] = [
        Overlay(char: ".  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [0])),
        Overlay(char: ".. ", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [1])),
        Overlay(char: "...", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [2])),
        Overlay(char: " ..", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [3])),
        Overlay(char: "  .", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [4])),
        // tiny bubble drifts up: b = (t*2)%10, dy = -1/tick (2px per tick → 2/8 per real tick)
        // b advances by 2 per tick → span=5 (10px / 2px per tick)
        Overlay(
            char: "o",
            tint: .rgb565(0x07FF), // BUDDY_CYAN
            path: .linear(
                originCol: gridCol(px: 67 - 28),
                originRow: gridRow(px: 6 + 18),
                dxPerTick: 0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 10
            )
        ),
    ]

    // ATTENTION: YEL "!" at (67-4, BUDDY_Y_OVERLAY) period 4, active {2,3}
    //            RED "!" at (67+4, BUDDY_Y_OVERLAY+4) period 6, active {3,4,5}
    private static let attention: [Overlay] = [
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 - 4), row: gridRow(px: 6)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 + 4), row: gridRow(px: 6 + 4)),
            visibility: .tickMod(period: 6, activeTicks: [3, 4, 5])
        ),
    ]

    // CELEBRATE: 7 confetti streams raining down
    // phase = (t*2 + i*9) % 24; x = 67-36+i*12; y = BUDDY_Y_OVERLAY-6+phase
    // cols: YEL, HEART, CYAN, WHITE, GREEN, PURPLE (6-color cycle)
    // char: (i + t/2)&1 ? "*" : "o" → static per stream: i.isMultiple(of:2) ? "o" : "*"
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
                    originCol: gridCol(px: 67 - 36 + i * 12),
                    originRow: gridRow(px: 6 - 6),
                    dxPerTick: 0,
                    dyPerTick: 2.0 / 8.0,
                    phase: Double(i * 9),
                    span: 24
                )
            )
        }
    }()

    // DIZZY: three orbiting symbols — CYAN "*", YEL "*", HEART "o"
    // OX = [0,5,7,5,0,-5,-7,-5], OY = [-5,-3,0,3,5,3,0,-3]
    // p1=t%8, p2=(t+4)%8, p3=(t+2)%8
    // at (67+OX[p]-2, BUDDY_Y_OVERLAY+6+OY[p])
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
            Overlay(char: "o", tint: .rgb565(0xF810), path: .baked(orbitPoints(startOffset: 2))),
        ]
    }()

    // HEART: 5 heart-rise streams over 16 ticks (jitter drop per approved rules)
    // + pink bubble: HEART at (67+26, BUDDY_Y_OVERLAY+16 - b), b = (t+3)%14
    //   alternates "o"/"O" by (b&1); use "o" static (approved drop)
    private static let heart: [Overlay] = {
        var overlays = (0..<5).map { i in
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
        // pink bubble drifts up span=14, phase=3 (offset from t+3)
        overlays.append(
            Overlay(
                char: "o",
                tint: .rgb565(0xF810), // BUDDY_HEART
                path: .linear(
                    originCol: gridCol(px: 67 + 26),
                    originRow: gridRow(px: 6 + 16),
                    dxPerTick: 0,
                    dyPerTick: -1.0 / 8.0,
                    phase: 3,
                    span: 14
                )
            )
        )
        return overlays
    }()
}
