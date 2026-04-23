// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * Covers the pure [parseLogLine] helper that splits parsedEntries strings
 * into (time, message) for the NORMAL-tab log list. Mirrors iOS LogLine
 * init(parsed:) behaviour at HomeScreen.swift:1063-1072.
 */
class ParseLogLineTest {

    @Test fun timePrefixedEntrySplitsIntoTimeAndMessage() {
        val line = parseLogLine("12:34:56 device approved")
        assertEquals("12:34:56", line.time)
        assertEquals("device approved", line.message)
    }

    @Test fun entryWithoutColonFallsBackToCurrentClock() {
        val line = parseLogLine("just a message with no clock")
        assertFalse(line.time.isEmpty())
        assertEquals("just a message with no clock", line.message)
    }

    @Test fun messageWithEmbeddedSpacesIsPreservedAfterFirstSplit() {
        val line = parseLogLine("00:00:01 multi word tail with spaces")
        assertEquals("00:00:01", line.time)
        assertEquals("multi word tail with spaces", line.message)
    }

    @Test fun singleTokenEntryFallsBackToCurrentClock() {
        val line = parseLogLine("single-token")
        assertFalse(line.time.isEmpty())
        assertEquals("single-token", line.message)
    }

    @Test fun emptyEntryFallsBackToCurrentClock() {
        val line = parseLogLine("")
        assertFalse(line.time.isEmpty())
        assertEquals("", line.message)
    }

    @Test fun firstTokenWithoutColonIsTreatedAsMessage() {
        // Defensive: the iOS impl only accepts head-as-time when it contains
        // ':' — otherwise the whole entry becomes the message.
        val line = parseLogLine("heartbeat missed")
        assertFalse(line.time.contains("heartbeat"))
        assertEquals("heartbeat missed", line.message)
    }

    @Test fun timestampWithTrailingColonStillHandled() {
        // Edge case: iOS uses contains(":"), so a token like "time:" counts.
        val line = parseLogLine("time: event body")
        assertEquals("time:", line.time)
        assertEquals("event body", line.message)
    }
}
