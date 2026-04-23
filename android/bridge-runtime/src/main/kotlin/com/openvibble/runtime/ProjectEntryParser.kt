// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

/**
 * A parsed heartbeat log entry. Desktop emits lines in the format
 * `HH:mm:ss event [project] tool` (see OpenVibbleDesktop/AppState.swift —
 * appendHookLine). Firmware-originated entries are shorter
 * (`HH:mm event detail`) and parse with `project == null`.
 */
data class ParsedEntry(
    val raw: String,
    val time: String,
    val event: String,
    val project: String?,
    val detail: String?,
)

object ProjectEntryParser {
    /**
     * Splits a heartbeat entry into its structured parts. Returns null if the
     * line is empty or lacks an event token. Malformed brackets keep the tail
     * as `detail` — we never drop information.
     */
    fun parse(raw: String): ParsedEntry? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null

        val firstSpace = trimmed.indexOf(' ')
        if (firstSpace < 0) return null
        val time = trimmed.substring(0, firstSpace)
        val afterTime = trimmed.substring(firstSpace + 1).trim()
        if (afterTime.isEmpty()) return null

        val (event, tail) = splitFirstToken(afterTime)
        val (project, detail) = extractProjectAndDetail(tail)

        return ParsedEntry(raw = raw, time = time, event = event, project = project, detail = detail)
    }

    private fun splitFirstToken(s: String): Pair<String, String> {
        val space = s.indexOf(' ')
        if (space < 0) return s to ""
        val head = s.substring(0, space)
        val tail = s.substring(space + 1).trim()
        return head to tail
    }

    private fun extractProjectAndDetail(tail: String): Pair<String?, String?> {
        if (tail.isEmpty()) return null to null
        if (tail.firstOrNull() != '[') return null to tail
        val close = tail.indexOf(']')
        if (close < 0) return null to tail

        val inner = tail.substring(1, close).trim()
        val afterClose = tail.substring(close + 1).trim()
        return inner.ifEmpty { null } to afterClose.ifEmpty { null }
    }
}
