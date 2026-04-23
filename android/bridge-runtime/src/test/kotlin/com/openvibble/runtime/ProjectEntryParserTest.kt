// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Mirrors iOS ProjectEntryParserTests.swift. Desktop emits lines shaped like
 * `"HH:mm:ss event [project] tool"` (AppState.appendHookLine). Firmware's own
 * entries (`"10:42 git push"`) lack brackets — they still parse, with
 * `project == null`.
 */
class ProjectEntryParserTest {

    @Test fun parsesFullDesktopFormat() {
        val parsed = ProjectEntryParser.parse("10:42:05 PermissionRequest [openvibble] Bash")
        assertEquals("10:42:05", parsed?.time)
        assertEquals("PermissionRequest", parsed?.event)
        assertEquals("openvibble", parsed?.project)
        assertEquals("Bash", parsed?.detail)
    }

    @Test fun parsesWithoutTool() {
        val parsed = ProjectEntryParser.parse("10:42:05 SessionStart [openvibble]")
        assertEquals("openvibble", parsed?.project)
        assertNull(parsed?.detail)
    }

    @Test fun parsesFirmwareEntryWithoutBrackets() {
        val parsed = ProjectEntryParser.parse("10:42 git push")
        assertEquals("10:42", parsed?.time)
        assertEquals("git", parsed?.event)
        assertNull(parsed?.project)
        assertEquals("push", parsed?.detail)
    }

    @Test fun parsesEventWithNoDetail() {
        val parsed = ProjectEntryParser.parse("10:46:00 done")
        assertEquals("done", parsed?.event)
        assertNull(parsed?.project)
        assertNull(parsed?.detail)
    }

    @Test fun parsesToolWithSpaces() {
        val parsed = ProjectEntryParser.parse("10:42 PermissionRequest [openvibble] git commit")
        assertEquals("openvibble", parsed?.project)
        assertEquals("git commit", parsed?.detail)
    }

    @Test fun projectNameWithSpacesAndSymbols() {
        val parsed = ProjectEntryParser.parse("10:42 SessionStart [my project v2]")
        assertEquals("my project v2", parsed?.project)
        assertNull(parsed?.detail)
    }

    @Test fun preservesRaw() {
        val raw = "10:42 PermissionRequest [openvibble] Bash"
        val parsed = ProjectEntryParser.parse(raw)
        assertEquals(raw, parsed?.raw)
    }

    @Test fun rejectsEmpty() {
        assertNull(ProjectEntryParser.parse(""))
        assertNull(ProjectEntryParser.parse("   "))
    }

    @Test fun rejectsSingleToken() {
        assertNull(ProjectEntryParser.parse("10:42"))
    }

    @Test fun unmatchedOpenBracketFallsBackToDetail() {
        val parsed = ProjectEntryParser.parse("10:42 Stop [openvibble")
        assertEquals("Stop", parsed?.event)
        assertNull(parsed?.project)
        assertEquals("[openvibble", parsed?.detail)
    }

    @Test fun emptyBracketsIsNilProject() {
        val parsed = ProjectEntryParser.parse("10:42 SessionStart [] Bash")
        assertNull(parsed?.project)
        assertEquals("Bash", parsed?.detail)
    }
}
