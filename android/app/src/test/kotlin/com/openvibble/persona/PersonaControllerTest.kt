// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import com.openvibble.nusperipheral.NusConnectionState
import com.openvibble.runtime.BridgeSnapshot
import com.openvibble.stats.InMemoryStatsStorage
import com.openvibble.stats.PersonaStatsStore
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PersonaControllerTest {

    /**
     * Fake clock that the test advances in lock-step with the coroutine
     * dispatcher. Avoids Thread.sleep or real wall-clock leakage.
     */
    private class FakeClock(start: Long = 10_000L) {
        var nowMs: Long = start
        fun reader(): () -> Long = { nowMs }
    }

    private class Harness(scope: TestScope) {
        val snapshot = MutableStateFlow(BridgeSnapshot.empty)
        val connection = MutableStateFlow<NusConnectionState>(NusConnectionState.Stopped)
        val recentLevelUp = MutableStateFlow(false)
        val lastQuickApprovalAt = MutableStateFlow<Long?>(null)
        val lastCompletedAt = MutableStateFlow<Long?>(null)
        val clock = FakeClock()
        val stats = PersonaStatsStore(
            storage = InMemoryStatsStorage(),
            clock = { clock.nowMs },
            initialNow = clock.nowMs,
        )
        val controller = PersonaController(scope = scope, clock = clock.reader())

        fun bind() {
            controller.bind(
                snapshot = snapshot,
                connectionState = connection,
                recentLevelUp = recentLevelUp,
                lastQuickApprovalAt = lastQuickApprovalAt,
                lastCompletedAt = lastCompletedAt,
                stats = stats,
            )
        }

        fun close() {
            controller.unbind()
        }
    }

    // --- Derived state (no overlays active) ---

    @Test
    fun `state is IDLE when disconnected`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Stopped
            runCurrent()
            assertEquals(PersonaState.IDLE, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `state is IDLE when connected but nothing running`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            runCurrent()
            assertEquals(PersonaState.IDLE, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `state is BUSY when connected with running task`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            h.snapshot.value = BridgeSnapshot.empty.copy(running = 1)
            runCurrent()
            assertEquals(PersonaState.BUSY, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `state is ATTENTION when waiting outranks running`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            h.snapshot.value = BridgeSnapshot.empty.copy(running = 2, waiting = 1)
            runCurrent()
            assertEquals(PersonaState.ATTENTION, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `recentlyCompleted latches CELEBRATE even when disconnected`() =
        runTest(StandardTestDispatcher()) {
            val h = Harness(this).also { it.bind() }
            try {
                h.recentLevelUp.value = true
                runCurrent()
                assertEquals(PersonaState.CELEBRATE, h.controller.state.value)
            } finally {
                h.close()
            }
        }

    // --- Overlay priority: shake > heart > face-down > celebrate > derived ---

    @Test
    fun `shake overrides everything for SHAKE_DURATION_MS`() =
        runTest(StandardTestDispatcher()) {
            val h = Harness(this).also { it.bind() }
            try {
                h.connection.value = NusConnectionState.Connected(centralCount = 1)
                h.snapshot.value = BridgeSnapshot.empty.copy(running = 1)
                h.lastCompletedAt.value = h.clock.nowMs
                runCurrent()
                assertEquals(PersonaState.CELEBRATE, h.controller.state.value)

                h.controller.notifyShake()
                assertEquals(PersonaState.DIZZY, h.controller.state.value)

                // Advance the fake clock past the shake window; celebrate still
                // in its longer window should reassert on the next tick.
                h.clock.nowMs += PersonaController.SHAKE_DURATION_MS + 10L
                advanceTimeBy(PersonaController.TICK_PERIOD_MS + 10L)
                assertEquals(PersonaState.CELEBRATE, h.controller.state.value)
            } finally {
                h.close()
            }
        }

    @Test
    fun `heart beats celebrate when both active`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            h.lastQuickApprovalAt.value = h.clock.nowMs
            h.lastCompletedAt.value = h.clock.nowMs
            runCurrent()
            assertEquals(PersonaState.HEART, h.controller.state.value)

            // Let heart expire; celebrate should still be in its window.
            h.clock.nowMs += PersonaController.HEART_DURATION_MS + 10L
            advanceTimeBy(PersonaController.TICK_PERIOD_MS + 10L)
            assertEquals(PersonaState.CELEBRATE, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `face-down flips to SLEEP after the delay`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            runCurrent()

            h.controller.setFaceDown(true)
            // Immediately after, we are still within the delay.
            assertEquals(PersonaState.IDLE, h.controller.state.value)

            h.clock.nowMs += PersonaController.FACE_DOWN_SLEEP_DELAY_MS + 1L
            advanceTimeBy(PersonaController.TICK_PERIOD_MS + 10L)
            assertEquals(PersonaState.SLEEP, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `face-down release after sleep delay credits a nap`() =
        runTest(StandardTestDispatcher()) {
            val h = Harness(this).also { it.bind() }
            try {
                h.controller.setFaceDown(true)
                val napSeconds = 60L
                h.clock.nowMs += napSeconds * 1000L
                h.controller.setFaceDown(false)

                assertEquals(napSeconds, h.stats.stats.value.napSeconds)
            } finally {
                h.close()
            }
        }

    @Test
    fun `face-down release before sleep delay credits nothing`() =
        runTest(StandardTestDispatcher()) {
            val h = Harness(this).also { it.bind() }
            try {
                h.controller.setFaceDown(true)
                h.clock.nowMs += PersonaController.FACE_DOWN_SLEEP_DELAY_MS - 100L
                h.controller.setFaceDown(false)

                assertEquals(0L, h.stats.stats.value.napSeconds)
            } finally {
                h.close()
            }
        }

    @Test
    fun `quick approval triggers HEART`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            runCurrent()

            h.lastQuickApprovalAt.value = h.clock.nowMs
            runCurrent()
            assertEquals(PersonaState.HEART, h.controller.state.value)
        } finally {
            h.close()
        }
    }

    @Test
    fun `celebrate expires back to derived state`() = runTest(StandardTestDispatcher()) {
        val h = Harness(this).also { it.bind() }
        try {
            h.connection.value = NusConnectionState.Connected(centralCount = 1)
            runCurrent()

            h.lastCompletedAt.value = h.clock.nowMs
            runCurrent()
            assertEquals(PersonaState.CELEBRATE, h.controller.state.value)

            h.clock.nowMs += PersonaController.CELEBRATE_DURATION_MS + 10L
            advanceTimeBy(PersonaController.TICK_PERIOD_MS + 10L)
            assertEquals(PersonaState.IDLE, h.controller.state.value)
        } finally {
            h.close()
        }
    }
}
