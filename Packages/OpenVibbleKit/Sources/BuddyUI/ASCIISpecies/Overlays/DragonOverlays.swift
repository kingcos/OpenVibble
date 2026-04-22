import BuddyPersona

// Firmware px → grid coords
// BUDDY_X_CENTER=67, sprite left=31 (67-36), BUDDY_Y_BASE=30, BUDDY_CHAR_W=6, BUDDY_CHAR_H=8
private func gridCol(px: Int) -> Double { Double(px - 31) / 6.0 }
private func gridRow(px: Int) -> Double { Double(px - 30) / 8.0 }

enum DragonOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        .idle: idle,
        .busy: busy,
        .attention: attention,
        .celebrate: celebrate,
        .dizzy: dizzy,
        .heart: heart,
    ]

    // SLEEP: two Z-streams + one smoke ring drifting up
    // DIM   "z" at (67+22+p1,  BUDDY_Y_OVERLAY+18 - p1*2) p1 = t%10
    // WHITE "Z" at (67+28+p2,  BUDDY_Y_OVERLAY+12 - p2)   p2 = (t+4)%10
    // DIM   "o" at (67+18,     BUDDY_Y_OVERLAY+16 - p3)   p3 = (t+7)%12  — smoke ring fixed x
    private static let sleep: [Overlay] = [
        Overlay(
            char: "z",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 22),
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
                originCol: gridCol(px: 67 + 28),
                originRow: gridRow(px: 6 + 12),
                dxPerTick: 1.0 / 6.0,
                dyPerTick: -1.0 / 8.0,
                phase: 4,
                span: 10
            )
        ),
        // Smoke ring: fixed x, drifts up; starts at BUDDY_Y_OVERLAY+16, rises over 12 ticks
        Overlay(
            char: "o",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 18),
                originRow: gridRow(px: 6 + 16),
                dxPerTick: 0,
                dyPerTick: -1.0 / 8.0,
                phase: 7,
                span: 12
            )
        ),
    ]

    // IDLE: tiny smoke/dot from nostril when pose == SNIFF(6) or PUFF_R(7)
    // s = (t&7); "." or "o" alternating by (s&1), DIM color
    // at (67 + (pose==7 ? 14 : 0), BUDDY_Y_OVERLAY-4-s) drifts up
    // Approved approximation: pick the pose==7 branch (x+14); note that pose==6 uses x+0.
    // We port both as two overlays, each always-visible. In practice only one pose fires at a time
    // but we can't gate on pose here — use always-visible at pose==7 branch (x+14) as primary.
    // Per approved: pick one branch → use x=0 (pose==6/SNIFF branch)
    // The smoke cycles "." and "o" per (s&1) — map as two overlays tickMod period=2
    private static let idle: [Overlay] = [
        // s even: "."  at (67+0, BUDDY_Y_OVERLAY-4-s) rising; s=t&7 → period 16 (8*2 = not right)
        // s = t & 7 so s runs 0..7 each 8 ticks, dy rises 1 per tick
        // model as linear span=8 with alternating char: "." for even ticks, "o" for odd
        Overlay(
            char: ".",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 0),
                originRow: gridRow(px: 6 - 4),
                dxPerTick: 0,
                dyPerTick: -1.0 / 8.0,
                phase: 0,
                span: 8
            ),
            visibility: .tickMod(period: 2, activeTicks: [0])
        ),
        Overlay(
            char: "o",
            tint: .dim,
            path: .linear(
                originCol: gridCol(px: 67 + 0),
                originRow: gridRow(px: 6 - 4),
                dxPerTick: 0,
                dyPerTick: -1.0 / 8.0,
                phase: 1,
                span: 8
            ),
            visibility: .tickMod(period: 2, activeTicks: [1])
        ),
    ]

    // BUSY: gold coins ticker at (67+22, BUDDY_Y_OVERLAY+14) YEL, t%6
    // COINS = { "$  ", "$$ ", "$$$", " $$", "  $", "   " }
    // + sparkle: WHITE "*" at (67+24, BUDDY_Y_OVERLAY+10) gated (t/2)&1 → period 4, active {2,3}
    private static let busy: [Overlay] = [
        Overlay(char: "$  ", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [0])),
        Overlay(char: "$$ ", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [1])),
        Overlay(char: "$$$", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [2])),
        Overlay(char: " $$", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [3])),
        Overlay(char: "  $", tint: .rgb565(0xFFE0), path: .fixed(col: gridCol(px: 67 + 22), row: gridRow(px: 6 + 14)), visibility: .tickMod(period: 6, activeTicks: [4])),
        // entry 5 "   " blank — skip
        // Sparkle on pile
        Overlay(
            char: "*",
            tint: .white,
            path: .fixed(col: gridCol(px: 67 + 24), row: gridRow(px: 6 + 10)),
            visibility: .tickMod(period: 4, activeTicks: [2, 3])
        ),
    ]

    // ATTENTION: two "!" flashers + flame puff when pose==3 or pose==4
    // YEL "!" at (67-6, BUDDY_Y_OVERLAY)       period 4, active {2,3}
    // RED "!" at (67+6, BUDDY_Y_OVERLAY+4)      period 6, active {3,4,5}
    // Flame puff "^" at (67+18, BUDDY_Y_OVERLAY+12 - (t*2)%8), YEL
    //   gated on pose==3||4; approx: always-visible (pose-gating not supported)
    //   position: y = 6+12 - (t*2)%8 → drifts up by 2 per tick, span=4, wraps
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
        // Flame puff: y = BUDDY_Y_OVERLAY+12 - (t*2)%8; drifts up 2px per tick, span=4 ticks
        // origin at BUDDY_Y_OVERLAY+12, dy = -2/8 per tick, span=4
        Overlay(
            char: "^",
            tint: .rgb565(0xFFE0), // BUDDY_YEL
            path: .linear(
                originCol: gridCol(px: 67 + 18),
                originRow: gridRow(px: 6 + 12),
                dxPerTick: 0,
                dyPerTick: -2.0 / 8.0,
                phase: 0,
                span: 4
            )
        ),
    ]

    // CELEBRATE: 6 confetti streams raining down
    // phase = (t*2 + i*11) % 22; x = 67-36+i*14
    // cols: YEL, HEART, CYAN, WHITE, GREEN (5-color)
    // char: (i + t/2)&1 ? "$" : "*" → static: i.isMultiple(of:2) ? "*" : "$"
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
                char: i.isMultiple(of: 2) ? "*" : "$",
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

    // DIZZY: three orbiting symbols — CYAN "*", YEL "*", WHITE "$"
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
            Overlay(char: "$", tint: .white, path: .baked(orbitPoints(startOffset: 2))),
        ]
    }()

    // HEART: 5 heart-rise streams over 16 ticks (jitter drop per approved rules)
    // + lovesick smoke ring: DIM "o" at (67+14, BUDDY_Y_OVERLAY+14 - sp), sp=(t*2)%18
    //   sp advances 2 per tick → span=9 ticks (18/2)
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
        // lovesick smoke ring drifts up; sp = (t*2)%18 → dy = -2/8 per tick, span=9
        overlays.append(
            Overlay(
                char: "o",
                tint: .dim,
                path: .linear(
                    originCol: gridCol(px: 67 + 14),
                    originRow: gridRow(px: 6 + 14),
                    dxPerTick: 0,
                    dyPerTick: -2.0 / 8.0,
                    phase: 0,
                    span: 9
                )
            )
        )
        return overlays
    }()
}
