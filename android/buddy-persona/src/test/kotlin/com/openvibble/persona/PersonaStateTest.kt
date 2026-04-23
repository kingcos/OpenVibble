// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class PersonaStateTest {

    @Test
    fun derive_disconnected_returnsIdle() {
        val s = derivePersonaState(
            PersonaDeriveInput(connected = false, sessionsRunning = 5, sessionsWaiting = 5, recentlyCompleted = false)
        )
        assertEquals(PersonaState.IDLE, s)
    }

    @Test
    fun derive_recentlyCompleted_overridesEverything() {
        val s = derivePersonaState(
            PersonaDeriveInput(connected = true, sessionsRunning = 3, sessionsWaiting = 2, recentlyCompleted = true)
        )
        assertEquals(PersonaState.CELEBRATE, s)
    }

    @Test
    fun derive_waiting_returnsAttention() {
        val s = derivePersonaState(
            PersonaDeriveInput(connected = true, sessionsRunning = 0, sessionsWaiting = 1, recentlyCompleted = false)
        )
        assertEquals(PersonaState.ATTENTION, s)
    }

    @Test
    fun derive_running_returnsBusy() {
        val s = derivePersonaState(
            PersonaDeriveInput(connected = true, sessionsRunning = 1, sessionsWaiting = 0, recentlyCompleted = false)
        )
        assertEquals(PersonaState.BUSY, s)
    }

    @Test
    fun derive_idle_whenConnectedButIdle() {
        val s = derivePersonaState(
            PersonaDeriveInput(connected = true, sessionsRunning = 0, sessionsWaiting = 0, recentlyCompleted = false)
        )
        assertEquals(PersonaState.IDLE, s)
    }

    @Test
    fun overlay_dizzyBeforeExpiryWins() {
        val now = 1_000_000L
        val result = resolvePersonaState(
            PersonaState.BUSY,
            PersonaOverlay.Dizzy(untilEpochMs = now + 1),
            now,
        )
        assertEquals(PersonaState.DIZZY, result)
    }

    @Test
    fun overlay_dizzyAfterExpiryFallsBack() {
        val now = 1_000_000L
        val result = resolvePersonaState(
            PersonaState.BUSY,
            PersonaOverlay.Dizzy(untilEpochMs = now - 1),
            now,
        )
        assertEquals(PersonaState.BUSY, result)
    }

    @Test
    fun overlay_heartBeforeExpiryWins() {
        val now = 1_000_000L
        val result = resolvePersonaState(
            PersonaState.IDLE,
            PersonaOverlay.Heart(untilEpochMs = now + 1),
            now,
        )
        assertEquals(PersonaState.HEART, result)
    }

    @Test
    fun overlay_sleepRequires3Seconds() {
        val now = 1_000_000L
        val notYet = resolvePersonaState(
            PersonaState.IDLE,
            PersonaOverlay.Sleep(sinceEpochMs = now - 1_000),
            now,
        )
        assertEquals(PersonaState.IDLE, notYet)

        val elapsed = resolvePersonaState(
            PersonaState.IDLE,
            PersonaOverlay.Sleep(sinceEpochMs = now - 4_000),
            now,
        )
        assertEquals(PersonaState.SLEEP, elapsed)
    }

    @Test
    fun slugsAreNonEmpty() {
        for (state in PersonaState.values()) {
            assertFalse(state.slug.isEmpty())
        }
    }
}
