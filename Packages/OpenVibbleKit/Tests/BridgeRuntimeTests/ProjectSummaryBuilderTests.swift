// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import BridgeRuntime

/// ProjectSummaryBuilder groups the flat heartbeat entries list (shared with
/// BridgeAppModel.parsedEntries — newest first) into per-project buckets with
/// an activity flag, and threads the "who owns the current prompt" bit down
/// from BridgeAppModel.
struct ProjectSummaryBuilderTests {
    @Test func groupsEntriesByProject() {
        let entries = [
            "10:45 UserPromptSubmit [alpha]",
            "10:44 SessionStart [beta]",
            "10:43 SessionStart [alpha]"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out.map(\.name) == ["alpha", "beta"])
        #expect(out[0].entries.count == 2)
        #expect(out[1].entries.count == 1)
    }

    @Test func ignoresEntriesWithoutProject() {
        let entries = [
            "10:45 git push",
            "10:44 SessionStart [alpha]"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out.map(\.name) == ["alpha"])
    }

    @Test func activeWhenNewestEventIsNotTerminal() {
        let entries = ["10:45 UserPromptSubmit [alpha]"]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out[0].isActive == true)
    }

    @Test func inactiveWhenNewestEventIsStop() {
        let entries = [
            "10:46 Stop [alpha]",
            "10:45 UserPromptSubmit [alpha]"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out[0].isActive == false)
    }

    @Test func inactiveWhenNewestEventIsSessionEnd() {
        let entries = ["10:45 SessionEnd [alpha]"]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out[0].isActive == false)
    }

    @Test func promptOwnerDerivedFromLatestPermissionRequest() {
        let entries = [
            "10:46 PermissionRequest [beta] Bash",
            "10:45 PermissionRequest [alpha] Bash"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: true)
        let beta = out.first { $0.name == "beta" }
        let alpha = out.first { $0.name == "alpha" }
        #expect(beta?.hasPendingPrompt == true)
        #expect(alpha?.hasPendingPrompt == false)
    }

    @Test func noPromptOwnerWhenHasPromptFalse() {
        let entries = ["10:46 PermissionRequest [beta] Bash"]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out[0].hasPendingPrompt == false)
    }

    @Test func promptOwnerFliesToFront() {
        let entries = [
            "10:45 UserPromptSubmit [alpha]",
            "10:44 PermissionRequest [beta] Bash"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: true)
        #expect(out.map(\.name) == ["beta", "alpha"])
    }

    @Test func activeBubblesAboveInactive() {
        let entries = [
            "10:47 Stop [alpha]",
            "10:46 SessionStart [alpha]",
            "10:45 UserPromptSubmit [beta]"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out.map(\.name) == ["beta", "alpha"])
    }

    @Test func tiebreakByDiscoveryOrder() {
        let entries = [
            "10:47 UserPromptSubmit [alpha]",
            "10:46 UserPromptSubmit [beta]",
            "10:45 UserPromptSubmit [gamma]"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out.map(\.name) == ["alpha", "beta", "gamma"])
    }

    @Test func entriesInsideBucketStayNewestFirst() {
        let entries = [
            "10:47 PermissionRequest [alpha] Bash",
            "10:45 SessionStart [alpha]"
        ]
        let out = ProjectSummaryBuilder.build(entries: entries, hasPrompt: false)
        #expect(out[0].entries.map(\.event) == ["PermissionRequest", "SessionStart"])
    }

    @Test func emptyEntriesYieldsEmptyList() {
        #expect(ProjectSummaryBuilder.build(entries: [], hasPrompt: false).isEmpty)
    }
}
