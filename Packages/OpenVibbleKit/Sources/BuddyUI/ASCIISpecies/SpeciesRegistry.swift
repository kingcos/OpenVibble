import Foundation
import BuddyPersona

/// Maps firmware species index (see `PersonaSpeciesCatalog.names`) to an
/// `ASCIIAnimation` provider.
///
/// iOS only ships full hand-tuned frame tables for cat today, so we derive
/// the other firmware species by applying per-species glyph styling on top of
/// cat's motion curves. This keeps all species visually distinct (matching the
/// "species switch should change appearance" expectation) while preserving a
/// single, stable animation timing source.
public enum SpeciesRegistry {
    public static func animation(forIdx idx: Int, state: PersonaState) -> ASCIIAnimation {
        let base = CatSpecies.animation(for: state)
        guard idx != 4, let style = style(for: idx) else {
            return base
        }
        return remap(base: base, style: style)
    }

    private struct GlyphStyle {
        let headToken: String // 5-char token replacing core cat head glyphs
        let map: [Character: Character]
    }

    private static let headPatterns: [String] = [
        "/\\_/\\",
        "/^_^\\",
        "/\\-/\\",
        "<\\_/\\",
        "/\\_/>"
    ]

    private static func style(for idx: Int) -> GlyphStyle? {
        switch idx {
        case 0: // capybara
            return GlyphStyle(headToken: "(u_u)", map: [
                "w": "n", "v": "n", "~": "=", "P": "u", "^": "u"
            ])
        case 1: // duck
            return GlyphStyle(headToken: "(___)", map: [
                "w": ">", "v": ">", "u": "c", "^": ".", "~": "-"
            ])
        case 2: // goose
            return GlyphStyle(headToken: "(^^^)", map: [
                "w": "V", "v": "V", "u": "U", "^": "A", "~": "-"
            ])
        case 3: // blob
            return GlyphStyle(headToken: "~~~~~", map: [
                "/": "(", "\\": ")", "o": "*", "O": "*", "w": "o", "v": "o", "u": "o"
            ])
        case 5: // dragon
            return GlyphStyle(headToken: "/^^^\\", map: [
                "_": "^", "w": "M", "v": "M", "u": "m", "O": "0", "~": "^"
            ])
        case 6: // octopus
            return GlyphStyle(headToken: "(ooo)", map: [
                "/": "(", "\\": ")", "\"": "~", "'": "~"
            ])
        case 7: // owl
            return GlyphStyle(headToken: "/o_o\\", map: [
                "o": "O", "w": "v", "^": "A"
            ])
        case 8: // penguin
            return GlyphStyle(headToken: "|o_o|", map: [
                "/": "|", "\\": "|", "w": "u", "v": "u", "~": "-"
            ])
        case 9: // turtle
            return GlyphStyle(headToken: "/===\\", map: [
                "_": "=", "w": "n", "v": "n", "~": "="
            ])
        case 10: // snail
            return GlyphStyle(headToken: "(o@o)", map: [
                "/": "(", "\\": ")", "w": "c", "v": "c", "~": "@"
            ])
        case 11: // ghost
            return GlyphStyle(headToken: "/...\\", map: [
                "o": ".", "O": ".", "@": ".", "x": ".", "w": "~", "v": "~", "u": "~"
            ])
        case 12: // axolotl
            return GlyphStyle(headToken: "/x_x\\", map: [
                "o": "x", "O": "X", "@": "x", "w": "u", "v": "u", "^": "~"
            ])
        case 13: // cactus
            return GlyphStyle(headToken: "|^_^|", map: [
                "/": "|", "\\": "|", "o": "*", "O": "*", "w": "n", "v": "n"
            ])
        case 14: // robot
            return GlyphStyle(headToken: "[0_0]", map: [
                "(": "[", ")": "]", "/": "|", "\\": "|", "o": "0", "O": "0",
                "@": "8", "w": "=", "v": "=", "u": "_", "^": "+", "~": "-"
            ])
        case 15: // rabbit
            return GlyphStyle(headToken: "/^_^\\", map: [
                "w": "w", "v": "v", "u": "u", "<": "/", ">": "\\"
            ])
        case 16: // mushroom
            return GlyphStyle(headToken: "/m_m\\", map: [
                "_": "-", "w": "m", "v": "m", "u": "m", "~": ":"
            ])
        case 17: // chonk
            return GlyphStyle(headToken: "(o_o)", map: [
                "/": "(", "\\": ")", "w": "m", "v": "m", "u": "m", "~": "_"
            ])
        default:
            return nil
        }
    }

    private static func remap(base: ASCIIAnimation, style: GlyphStyle) -> ASCIIAnimation {
        let poses = base.poses.map { frame in
            ASCIIFrame(frame.lines.map { line in
                remap(line: line, style: style)
            })
        }
        return ASCIIAnimation(
            poses: poses,
            sequence: base.sequence,
            ticksPerBeat: base.ticksPerBeat
        )
    }

    private static func remap(line: String, style: GlyphStyle) -> String {
        var out = line
        for pattern in headPatterns {
            out = out.replacingOccurrences(of: pattern, with: style.headToken)
        }
        out = String(out.map { style.map[$0] ?? $0 })
        return out
    }
}
