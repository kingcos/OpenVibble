// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A parsed heartbeat log entry. Desktop emits lines in the format
/// `HH:mm:ss event [project] tool` (see OpenVibbleDesktop/AppState.swift —
/// `appendHookLine`). Firmware-originated entries are shorter
/// (`HH:mm event detail`) and parse with `project == nil`.
public struct ParsedEntry: Equatable, Sendable {
    public let raw: String
    public let time: String
    public let event: String
    public let project: String?
    public let detail: String?

    public init(raw: String, time: String, event: String, project: String?, detail: String?) {
        self.raw = raw
        self.time = time
        self.event = event
        self.project = project
        self.detail = detail
    }
}

public enum ProjectEntryParser {
    /// Splits a heartbeat entry line into its structured parts. Returns nil
    /// if the line is empty or has only one whitespace-separated token (no
    /// event). Malformed brackets (`[` without matching `]`) keep the whole
    /// tail as `detail` — we never drop information.
    public static func parse(_ raw: String) -> ParsedEntry? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let firstSpace = trimmed.firstIndex(of: " ") else { return nil }
        let time = String(trimmed[..<firstSpace])
        let afterTime = trimmed[trimmed.index(after: firstSpace)...]
            .trimmingCharacters(in: .whitespaces)
        guard !afterTime.isEmpty else { return nil }

        let (event, tail) = splitFirstToken(afterTime)
        let (project, detail) = extractProjectAndDetail(from: tail)

        return ParsedEntry(raw: raw, time: time, event: event, project: project, detail: detail)
    }

    private static func splitFirstToken(_ s: String) -> (head: String, tail: String) {
        guard let space = s.firstIndex(of: " ") else { return (s, "") }
        let head = String(s[..<space])
        let tail = String(s[s.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        return (head, tail)
    }

    private static func extractProjectAndDetail(from tail: String) -> (project: String?, detail: String?) {
        guard !tail.isEmpty else { return (nil, nil) }
        guard tail.first == "[", let close = tail.firstIndex(of: "]") else {
            return (nil, tail)
        }
        let inner = String(tail[tail.index(after: tail.startIndex)..<close])
            .trimmingCharacters(in: .whitespaces)
        let afterClose = tail[tail.index(after: close)...]
            .trimmingCharacters(in: .whitespaces)
        let project = inner.isEmpty ? nil : inner
        let detail = afterClose.isEmpty ? nil : String(afterClose)
        return (project, detail)
    }
}
