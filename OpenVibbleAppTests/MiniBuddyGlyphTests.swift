import XCTest
@testable import OpenVibbleApp

/// Ensures every PersonaState slug that the app emits via its Live Activity
/// payload corresponds to a non-empty glyph in the widget's PersonaGlyph view.
///
/// The widget target lives in a separate extension, so we mirror its glyph
/// map here — if the widget adds or removes a case, update both places.
final class MiniBuddyGlyphTests: XCTestCase {
    private let expectedSlugs = [
        "sleep", "idle", "busy", "attention", "celebrate", "dizzy", "heart"
    ]

    func testEverySlugHasGlyph() {
        for slug in expectedSlugs {
            let glyph = personaGlyph(for: slug)
            XCTAssertFalse(glyph.isEmpty, "slug \(slug) is missing a glyph")
        }
    }

    func testUnknownSlugFallsBackToIdleGlyph() {
        XCTAssertEqual(personaGlyph(for: "totally-unknown"), personaGlyph(for: "idle"))
    }

    func testDistinctStatesMapToDistinctGlyphs() {
        var seen = Set<String>()
        for slug in expectedSlugs {
            XCTAssertTrue(seen.insert(personaGlyph(for: slug)).inserted,
                          "slug \(slug) collides with another state")
        }
    }
}

/// Mirror of the widget-target glyph map. Keep in sync with PersonaGlyph.
func personaGlyph(for slug: String) -> String {
    switch slug {
    case "sleep":     return "[z]"
    case "busy":      return "[*]"
    case "attention": return "[!]"
    case "celebrate": return "[+]"
    case "dizzy":     return "[~]"
    case "heart":     return "[♥]"
    case "idle":      return "[.]"
    default:          return "[.]"
    }
}
