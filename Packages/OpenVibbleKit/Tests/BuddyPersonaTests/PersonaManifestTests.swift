// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
@testable import BuddyPersona

final class PersonaManifestTests: XCTestCase {
    func test_parse_singleFrame_string() throws {
        let json = """
        {"name":"bufo","mode":"gif","states":{"idle":"idle.gif"}}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(PersonaManifest.self, from: json)
        XCTAssertEqual(m.name, "bufo")
        XCTAssertEqual(m.mode, .gif)
        XCTAssertEqual(m.frames(for: "idle")?.filenames, ["idle.gif"])
    }

    func test_parse_variants_array() throws {
        let json = """
        {"name":"bufo","states":{"busy":["b1.gif","b2.gif"]}}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(PersonaManifest.self, from: json)
        XCTAssertEqual(m.frames(for: "busy")?.filenames, ["b1.gif", "b2.gif"])
    }

    func test_parse_textState_object() throws {
        let json = """
        {"name":"ascii","mode":"text","states":{"idle":{"frames":["a","b"],"delay_ms":300}}}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(PersonaManifest.self, from: json)
        if case .text(let frames, let delay) = m.frames(for: "idle") {
            XCTAssertEqual(frames, ["a", "b"])
            XCTAssertEqual(delay, 300)
        } else {
            XCTFail("Expected .text state")
        }
    }

    func test_parse_missingStates_returnsEmpty() throws {
        let json = """
        {"name":"x"}
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(PersonaManifest.self, from: json)
        XCTAssertEqual(m.name, "x")
        XCTAssertNil(m.frames(for: "idle"))
    }

    func test_parse_invalidState_fails() {
        let json = """
        {"name":"bad","states":{"idle":42}}
        """.data(using: .utf8)!
        // The `states` dict decode fails → catch block makes states empty.
        let m = try? JSONDecoder().decode(PersonaManifest.self, from: json)
        XCTAssertNotNil(m)
        XCTAssertNil(m?.frames(for: "idle"))
    }
}
