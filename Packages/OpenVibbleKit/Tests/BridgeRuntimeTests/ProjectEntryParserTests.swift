// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import BridgeRuntime

/// ProjectEntryParser turns raw heartbeat `entries` strings into structured
/// `ParsedEntry` values so the iOS UI can group activity by `[project]`.
///
/// Desktop emits lines shaped like `"HH:mm:ss event [project] tool"`
/// (AppState.appendHookLine). The firmware's own entries (`"10:42 git push"`)
/// lack brackets — they still parse, with `project == nil`.
struct ProjectEntryParserTests {
    @Test func parsesFullDesktopFormat() {
        let parsed = ProjectEntryParser.parse("10:42:05 PermissionRequest [openvibble] Bash")
        #expect(parsed?.time == "10:42:05")
        #expect(parsed?.event == "PermissionRequest")
        #expect(parsed?.project == "openvibble")
        #expect(parsed?.detail == "Bash")
    }

    @Test func parsesWithoutTool() {
        let parsed = ProjectEntryParser.parse("10:42:05 SessionStart [openvibble]")
        #expect(parsed?.project == "openvibble")
        #expect(parsed?.detail == nil)
    }

    @Test func parsesFirmwareEntryWithoutBrackets() {
        let parsed = ProjectEntryParser.parse("10:42 git push")
        #expect(parsed?.time == "10:42")
        #expect(parsed?.event == "git")
        #expect(parsed?.project == nil)
        #expect(parsed?.detail == "push")
    }

    @Test func parsesEventWithNoDetail() {
        let parsed = ProjectEntryParser.parse("10:46:00 done")
        #expect(parsed?.event == "done")
        #expect(parsed?.project == nil)
        #expect(parsed?.detail == nil)
    }

    @Test func parsesToolWithSpaces() {
        let parsed = ProjectEntryParser.parse("10:42 PermissionRequest [openvibble] git commit")
        #expect(parsed?.project == "openvibble")
        #expect(parsed?.detail == "git commit")
    }

    @Test func projectNameWithSpacesAndSymbols() {
        let parsed = ProjectEntryParser.parse("10:42 SessionStart [my project v2]")
        #expect(parsed?.project == "my project v2")
        #expect(parsed?.detail == nil)
    }

    @Test func preservesRaw() {
        let raw = "10:42 PermissionRequest [openvibble] Bash"
        let parsed = ProjectEntryParser.parse(raw)
        #expect(parsed?.raw == raw)
    }

    @Test func rejectsEmpty() {
        #expect(ProjectEntryParser.parse("") == nil)
        #expect(ProjectEntryParser.parse("   ") == nil)
    }

    @Test func rejectsSingleToken() {
        #expect(ProjectEntryParser.parse("10:42") == nil)
    }

    @Test func unmatchedOpenBracketFallsBackToDetail() {
        let parsed = ProjectEntryParser.parse("10:42 Stop [openvibble")
        #expect(parsed?.event == "Stop")
        #expect(parsed?.project == nil)
        #expect(parsed?.detail == "[openvibble")
    }

    @Test func emptyBracketsIsNilProject() {
        let parsed = ProjectEntryParser.parse("10:42 SessionStart [] Bash")
        #expect(parsed?.project == nil)
        #expect(parsed?.detail == "Bash")
    }
}
