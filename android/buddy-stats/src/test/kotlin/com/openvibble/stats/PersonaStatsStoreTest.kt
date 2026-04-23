// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.stats

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PersonaStatsStoreTest {

    private fun newStore(storage: StatsStorage = InMemoryStatsStorage()): PersonaStatsStore =
        PersonaStatsStore(storage = storage, clock = { 0L }, initialNow = 0L)

    @Test
    fun onBridgeTokens_firstSightLatchesWithoutCrediting() {
        val store = newStore()
        store.onBridgeTokens(10_000L)
        assertEquals(0L, store.stats.value.tokens)
    }

    @Test
    fun onBridgeTokens_secondDeltaCredits() {
        val store = newStore()
        store.onBridgeTokens(10_000L)
        store.onBridgeTokens(12_000L)
        assertEquals(2_000L, store.stats.value.tokens)
    }

    @Test
    fun onBridgeTokens_bridgeRestartResyncsWithoutCrediting() {
        val store = newStore()
        store.onBridgeTokens(10_000L)
        store.onBridgeTokens(20_000L)
        assertEquals(10_000L, store.stats.value.tokens)
        store.onBridgeTokens(5_000L)
        assertEquals(10_000L, store.stats.value.tokens)
        store.onBridgeTokens(6_000L)
        assertEquals(11_000L, store.stats.value.tokens)
    }

    @Test
    fun onBridgeTokens_levelBoundaryReturnsTrue() {
        val store = newStore()
        store.onBridgeTokens(0L)
        val leveled = store.onBridgeTokens(60_000L)
        assertTrue(leveled)
        assertEquals(1, store.stats.value.level)
    }

    @Test
    fun onBridgeTokens_belowLevelBoundaryReturnsFalse() {
        val store = newStore()
        store.onBridgeTokens(0L)
        val leveled = store.onBridgeTokens(1_000L)
        assertFalse(leveled)
        assertEquals(0, store.stats.value.level)
    }

    @Test
    fun onApproval_updatesVelocityRing() {
        val store = newStore()
        store.onApproval(10.0)
        store.onApproval(20.0)
        val s = store.stats.value
        assertEquals(2, s.approvals)
        assertEquals(2, s.velCount)
        assertEquals(10, s.velocity[0])
        assertEquals(20, s.velocity[1])
    }

    @Test
    fun onDenial_increments() {
        val store = newStore()
        store.onDenial()
        assertEquals(1, store.stats.value.denials)
    }

    @Test
    fun reset_clearsStatsAndLatch() {
        val store = newStore()
        store.onBridgeTokens(10_000L)
        store.onBridgeTokens(12_000L)
        store.onApproval(5.0)
        assertNotEquals(0L, store.stats.value.tokens)

        store.reset()
        assertEquals(PersonaStats(), store.stats.value)

        store.onBridgeTokens(99_000L)
        assertEquals(0L, store.stats.value.tokens)
    }

    @Test
    fun energyTier_decaysOverTime() {
        val storage = InMemoryStatsStorage()
        val store = PersonaStatsStore(storage = storage, clock = { 0L }, initialNow = 0L)
        store.onNapEnd(60.0, now = 0L)
        assertEquals(5, store.energyTier(now = 0L))
        val fourHoursMs = 4 * 3_600_000L
        assertEquals(3, store.energyTier(now = fourHoursMs))
    }

    @Test
    fun persistence_roundTripsAcrossInstances() {
        val storage = InMemoryStatsStorage()
        val first = PersonaStatsStore(storage = storage, clock = { 0L }, initialNow = 0L)
        first.onApproval(12.0)
        first.onBridgeTokens(0L)
        first.onBridgeTokens(55_000L)
        assertEquals(1, first.stats.value.level)

        val reloaded = PersonaStatsStore(storage = storage, clock = { 0L }, initialNow = 0L)
        assertEquals(1, reloaded.stats.value.approvals)
        assertEquals(1, reloaded.stats.value.level)
    }
}
