// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Mirrors iOS ProjectSummaryBuilderTests.swift. Feeds newest-first `entries`
 * lists (same order BridgeAppModel uses) and asserts per-project grouping,
 * active flagging, and prompt-owner promotion to the front.
 */
class ProjectSummaryBuilderTest {

    @Test fun groupsEntriesByProject() {
        val entries = listOf(
            "10:45 UserPromptSubmit [alpha]",
            "10:44 SessionStart [beta]",
            "10:43 SessionStart [alpha]",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertEquals(listOf("alpha", "beta"), out.map { it.name })
        assertEquals(2, out[0].entries.size)
        assertEquals(1, out[1].entries.size)
    }

    @Test fun ignoresEntriesWithoutProject() {
        val entries = listOf(
            "10:45 git push",
            "10:44 SessionStart [alpha]",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertEquals(listOf("alpha"), out.map { it.name })
    }

    @Test fun activeWhenNewestEventIsNotTerminal() {
        val entries = listOf("10:45 UserPromptSubmit [alpha]")
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertTrue(out[0].isActive)
    }

    @Test fun inactiveWhenNewestEventIsStop() {
        val entries = listOf(
            "10:46 Stop [alpha]",
            "10:45 UserPromptSubmit [alpha]",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertFalse(out[0].isActive)
    }

    @Test fun inactiveWhenNewestEventIsSessionEnd() {
        val entries = listOf("10:45 SessionEnd [alpha]")
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertFalse(out[0].isActive)
    }

    @Test fun promptOwnerDerivedFromLatestPermissionRequest() {
        val entries = listOf(
            "10:46 PermissionRequest [beta] Bash",
            "10:45 PermissionRequest [alpha] Bash",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = true)
        val beta = out.first { it.name == "beta" }
        val alpha = out.first { it.name == "alpha" }
        assertTrue(beta.hasPendingPrompt)
        assertFalse(alpha.hasPendingPrompt)
    }

    @Test fun noPromptOwnerWhenHasPromptFalse() {
        val entries = listOf("10:46 PermissionRequest [beta] Bash")
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertFalse(out[0].hasPendingPrompt)
    }

    @Test fun promptOwnerFliesToFront() {
        val entries = listOf(
            "10:45 UserPromptSubmit [alpha]",
            "10:44 PermissionRequest [beta] Bash",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = true)
        assertEquals(listOf("beta", "alpha"), out.map { it.name })
    }

    @Test fun activeBubblesAboveInactive() {
        val entries = listOf(
            "10:47 Stop [alpha]",
            "10:46 SessionStart [alpha]",
            "10:45 UserPromptSubmit [beta]",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertEquals(listOf("beta", "alpha"), out.map { it.name })
    }

    @Test fun tiebreakByDiscoveryOrder() {
        val entries = listOf(
            "10:47 UserPromptSubmit [alpha]",
            "10:46 UserPromptSubmit [beta]",
            "10:45 UserPromptSubmit [gamma]",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertEquals(listOf("alpha", "beta", "gamma"), out.map { it.name })
    }

    @Test fun entriesInsideBucketStayNewestFirst() {
        val entries = listOf(
            "10:47 PermissionRequest [alpha] Bash",
            "10:45 SessionStart [alpha]",
        )
        val out = ProjectSummaryBuilder.build(entries, hasPrompt = false)
        assertEquals(listOf("PermissionRequest", "SessionStart"), out[0].entries.map { it.event })
    }

    @Test fun emptyEntriesYieldsEmptyList() {
        assertTrue(ProjectSummaryBuilder.build(emptyList(), hasPrompt = false).isEmpty())
    }
}
