// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.stats

import org.junit.Assert.assertEquals
import org.junit.Test

class PersonaStatsTest {

    @Test
    fun derivedLevel_matchesTokenBuckets() {
        assertEquals(0, PersonaStats(tokens = 0L).derivedLevel)
        assertEquals(0, PersonaStats(tokens = 49_999L).derivedLevel)
        assertEquals(1, PersonaStats(tokens = 50_000L).derivedLevel)
        assertEquals(2, PersonaStats(tokens = 125_000L).derivedLevel)
    }

    @Test
    fun fedProgress_acrossLevelBoundary() {
        assertEquals(0, PersonaStats(tokens = 0L).fedProgress)
        assertEquals(5, PersonaStats(tokens = 25_000L).fedProgress)
        assertEquals(9, PersonaStats(tokens = 49_999L).fedProgress)
        assertEquals(0, PersonaStats(tokens = 50_000L).fedProgress)
    }

    @Test
    fun medianVelocity_emptyReturnsZero() {
        assertEquals(0, PersonaStats().medianVelocitySeconds)
    }

    @Test
    fun medianVelocity_usesOnlyFilledSlots() {
        val s = PersonaStats(
            velocity = listOf(5, 15, 25, 0, 0, 0, 0, 0),
            velCount = 3,
        )
        assertEquals(15, s.medianVelocitySeconds)
    }

    @Test
    fun moodTier_fastResponderHighMood() {
        val s = PersonaStats(
            velocity = listOf(10, 0, 0, 0, 0, 0, 0, 0),
            velCount = 1,
            approvals = 5,
        )
        assertEquals(4, s.moodTier)
    }

    @Test
    fun moodTier_slowResponderLowMood() {
        val s = PersonaStats(
            velocity = listOf(200, 0, 0, 0, 0, 0, 0, 0),
            velCount = 1,
        )
        assertEquals(0, s.moodTier)
    }

    @Test
    fun moodTier_heavyDenyRatePullsDown() {
        val s = PersonaStats(
            velocity = listOf(10, 0, 0, 0, 0, 0, 0, 0),
            velCount = 1,
            approvals = 1,
            denials = 3,
        )
        assertEquals(2, s.moodTier)
    }
}
