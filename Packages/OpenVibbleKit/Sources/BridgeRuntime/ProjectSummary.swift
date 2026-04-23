// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A per-project view derived from the rolling heartbeat entries. Used by the
/// iOS INFO > CLAUDE page to split multi-session activity into horizontally
/// swipeable chips. The whole thing is recomputed from `entries` on every
/// update — there is no persistent store.
public struct ProjectSummary: Equatable, Sendable {
    public let name: String
    /// Entries belonging to this project, in the same order as the input
    /// (newest first, matching `BridgeAppModel.parsedEntries`).
    public let entries: [ParsedEntry]
    public let isActive: Bool
    public let hasPendingPrompt: Bool

    public init(name: String, entries: [ParsedEntry], isActive: Bool, hasPendingPrompt: Bool) {
        self.name = name
        self.entries = entries
        self.isActive = isActive
        self.hasPendingPrompt = hasPendingPrompt
    }
}

public enum ProjectSummaryBuilder {
    /// Desktop-side HookEvent raw values that signal "this project is no
    /// longer working" when they are the most recent entry for a project.
    /// Mirrors `HookBridge.HookEvent` — kept as string literals here so
    /// BridgeRuntime doesn't need to depend on HookBridge.
    private static let terminalEvents: Set<String> = ["Stop", "StopFailure", "SessionEnd"]

    /// Builds the per-project list from raw heartbeat entries (newest first).
    ///
    /// - Parameters:
    ///   - entries: Raw lines as received via `BridgeAppModel.parsedEntries`.
    ///   - hasPrompt: Whether `BridgeAppModel.prompt` is currently non-nil.
    ///                When true, the most recent `PermissionRequest` entry's
    ///                project is treated as owner of the pending prompt.
    public static func build(entries: [String], hasPrompt: Bool) -> [ProjectSummary] {
        let parsed = entries.compactMap(ProjectEntryParser.parse)
        let promptProject = hasPrompt ? findPromptProject(parsed: parsed) : nil

        var order: [String] = []
        var buckets: [String: [ParsedEntry]] = [:]
        for entry in parsed {
            guard let project = entry.project else { continue }
            if buckets[project] == nil {
                order.append(project)
                buckets[project] = []
            }
            buckets[project]?.append(entry)
        }

        let summaries = order.map { name -> ProjectSummary in
            let bucket = buckets[name] ?? []
            let newest = bucket.first
            let isActive: Bool = {
                guard let newest else { return false }
                return !terminalEvents.contains(newest.event)
            }()
            return ProjectSummary(
                name: name,
                entries: bucket,
                isActive: isActive,
                hasPendingPrompt: name == promptProject
            )
        }

        return sorted(summaries)
    }

    private static func findPromptProject(parsed: [ParsedEntry]) -> String? {
        for entry in parsed where entry.event == "PermissionRequest" {
            if let name = entry.project { return name }
        }
        return nil
    }

    private static func sorted(_ summaries: [ProjectSummary]) -> [ProjectSummary] {
        // Preserve original discovery order (newest-first appearance) as the
        // stable tiebreak; only lift prompt-owners / active projects above it.
        let indexed = summaries.enumerated().map { ($0.offset, $0.element) }
        let ordered = indexed.sorted { lhs, rhs in
            if lhs.1.hasPendingPrompt != rhs.1.hasPendingPrompt {
                return lhs.1.hasPendingPrompt
            }
            if lhs.1.isActive != rhs.1.isActive {
                return lhs.1.isActive
            }
            return lhs.0 < rhs.0
        }
        return ordered.map { $0.1 }
    }
}
