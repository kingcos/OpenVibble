// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.notifications

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Covers [PromptDecisionStore] — the durable broker between
 * [PromptActionReceiver] (which may fire while the app is killed) and the
 * running MainActivity. Uses the in-memory [InMemoryPromptDecisionPrefs] to
 * stay framework-free.
 */
class PromptDecisionStoreTest {

    private fun newStore() = PromptDecisionStore(InMemoryPromptDecisionPrefs())

    @Test fun drainReturnsNullWhenNothingStored() {
        assertNull(newStore().drainPending())
    }

    @Test fun writeThenDrainRoundTrips() {
        val store = newStore()
        store.writePendingDecision("abc123", PromptDecision.APPROVE)
        val pending = store.drainPending()
        assertNotNull(pending)
        assertEquals("abc123", pending!!.promptId)
        assertEquals(PromptDecision.APPROVE, pending.decision)
    }

    @Test fun drainConsumesSoSecondDrainReturnsNull() {
        val store = newStore()
        store.writePendingDecision("abc123", PromptDecision.DENY)
        store.drainPending()
        assertNull(store.drainPending())
    }

    @Test fun latestWriteWinsWhenUnconsumed() {
        val store = newStore()
        store.writePendingDecision("first", PromptDecision.APPROVE)
        store.writePendingDecision("second", PromptDecision.DENY)
        val pending = store.drainPending()!!
        assertEquals("second", pending.promptId)
        assertEquals(PromptDecision.DENY, pending.decision)
    }

    @Test fun emptyPromptIdIsIgnored() {
        val store = newStore()
        store.writePendingDecision("", PromptDecision.APPROVE)
        assertNull(store.drainPending())
    }

    @Test fun promptIdWithColonsRoundTrips() {
        // Non-printable separator — visible delimiters in the id must not
        // confuse decoding.
        val store = newStore()
        val id = "project:sess-1:tool:read"
        store.writePendingDecision(id, PromptDecision.APPROVE)
        val pending = store.drainPending()!!
        assertEquals(id, pending.promptId)
        assertEquals(PromptDecision.APPROVE, pending.decision)
    }

    @Test fun corruptedBlobDrainReturnsNullAndClears() {
        val prefs = InMemoryPromptDecisionPrefs()
        prefs.putString("pending", "malformed-no-separator")
        val store = PromptDecisionStore(prefs)
        assertNull(store.drainPending())
        // A subsequent drain must also be null — the corrupt record was cleared.
        assertNull(store.drainPending())
    }

    @Test fun decisionValueEchoesEnum() {
        val store = newStore()
        for (d in PromptDecision.values()) {
            store.writePendingDecision("id", d)
            assertEquals(d, store.drainPending()!!.decision)
        }
    }
}
