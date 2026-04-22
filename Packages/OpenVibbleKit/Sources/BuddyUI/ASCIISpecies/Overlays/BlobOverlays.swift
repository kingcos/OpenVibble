import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum BlobOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
        // .idle has no overlays per firmware
    ]

    // SLEEP: three Z-streams drift up-right over 10 ticks
    // DIM   "z" at (67+20+p1,   BUDDY_Y_OVERLAY+18 - p1*2) p1 = t%10
    // WHITE "Z" at (67+26+p2,   BUDDY_Y_OVERLAY+14 - p2)   p2 = (t+4)%10
    // DIM   "z" at (67+16+p3/2, BUDDY_Y_OVERLAY+10 - p3/2) p3 = (t+7)%10
    // + slow droplet: 0x07F0 "." at (67-6, BUDDY_Y_BASE+26+dphase), dphase=(t/2)%12
    //   visible only when dphase < 8 → tickMod period=24, activeTicks=[0..15]
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
            tint: .white,
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
        // Slow droplet falls below puddle: dphase = (t/2)%12, visible when dphase<8
        // dphase advances 1 per 2 ticks → period=24 (12 * 2), active ticks [0..15] (dphase 0..7)
        // Position: y = BUDDY_Y_BASE+26+dphase → starts at BUDDY_Y_BASE+26, drifts down
        // BUDDY_Y_BASE=30, so pixel y starts at 56 → gridRow(56) = (56-30)/8 = 3.25, drifts down
        Overlay(
            char: ".",
            tint: .rgb565(0x07F0), // blob green
            path: .linear(
                originCol: gridCol(px: 67 - 6),
                originRow: gridRow(px: 30 + 26),
                dxPerTick: 0,
                dyPerTick: 0.5 / 8.0, // dphase advances 0.5 per tick (1 per 2 ticks)
                phase: 0,
                span: 24
            ),
            visibility: .tickMod(period: 24, activeTicks: Array(0..<16))
        ),
    ]

    // BUSY: DOTS ticker at (67+22, BUDDY_Y_OVERLAY+14) WHITE, t%6
    // + tiny bubble rising inside slime: CYAN "o" at (67-2, BUDDY_Y_OVERLAY+18-b), b=(t/2)%8
    //   visible when b<6 → tickMod period=16, activeTicks=[0..11] (b 0..5, each lasts 2 ticks)
    private static let busy: [Overlay] = [
        Overlay(char: ".  ", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [0])),
        Overlay(char: ".. ", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [1])),
        Overlay(char: "...", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [2])),
        Overlay(char: " ..", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [3])),
        Overlay(char: "  .", tint: .white, path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [4])),
        // tiny CYAN bubble drifts up; b = (t/2)%8, so advances 0.5/tick → span=16 (8*2)
        // visible when b<6 → first 12 ticks of 16-tick period
        Overlay(
            char: "o",
            tint: .rgb565(0x07FF), // BUDDY_CYAN
            path: .linear(
                originCol: gridCol(px: 67 - 2),
                originRow: gridRow(px: 6 + 18),
                dxPerTick: 0,
                dyPerTick: -0.5 / 8.0, // b advances 0.5/tick
                phase: 0,
                span: 16
            ),
            visibility: .tickMod(period: 16, activeTicks: Array(0..<12))
        ),
    ]

    // ATTENTION: three "!" flashers
    // YEL "!" at (67-8, BUDDY_Y_OVERLAY-4)   if (t/2)&1  → period 4, active {2,3}
    // RED "!" at (67+8, BUDDY_Y_OVERLAY)      if (t/3)&1  → period 6, active {3,4,5}
    // YEL "!" at (67,   BUDDY_Y_OVERLAY-8)   if (t/4)&1  → period 8, active {4,5,6,7}
    private static let attention: [Overlay] = [
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67 - 8), row: gridRow(px: 6 - 4)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xF800), // BUDDY_RED
            path: .fixed(col: gridCol(px: 67 + 8), row: gridRow(px: 6)),
            visibility: .tickMod(period: 6, activeTicks: [3, 4, 5])
        ),
        Overlay(
            char: "!",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .fixed(col: gridCol(px: 67), row: gridRow(px: 6 - 8)),
            visibility: .tickMod(period: 8, activeTicks: [4, 5, 6, 7])
        ),
    ]

    // CELEBRATE: 6 confetti/droplet streams raining down
    // phase = (t*2 + i*11) % 22; x = 67-36+i*14; y = BUDDY_Y_OVERLAY-6+phase
    // cols: YEL, HEART, CYAN, 0x07F0 (blob green), GREEN (5-color cycle)
    // char: (i + t/2)&1 ? "*" : "o" → static per stream: i.isMultiple(of:2) ? "o" : "*"
    private static let celebrate: [Overlay] = {
        let palette: [OverlayTint] = [
            .rgb565(0xFFE0), // YEL
            .rgb565(0xF810), // HEART
            .rgb565(0x07FF), // CYAN
            .rgb565(0x07F0), // blob green
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

    // DIZZY: three orbiting symbols — CYAN "*", YEL "*", WHITE "o"
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
            Overlay(char: "o", tint: .white, path: .baked(orbitPoints(startOffset: 2))),
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
