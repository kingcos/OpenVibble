// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import com.openvibble.bridge.BridgeAppModel
import com.openvibble.nusperipheral.NusConnectionState
import com.openvibble.stats.PersonaStatsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Android parity with iOS `PersonaController` (OpenVibbleApp/PersonaController.swift).
 *
 * Consumes heartbeat/connection state from [BridgeAppModel] and emits a
 * [PersonaState] that drives the ASCII buddy. Time-gated overlays (shake →
 * dizzy, quick-approval → heart, completed-task → celebrate, face-down →
 * sleep) are layered on top of the derived base state.
 *
 * Motion inputs (`notifyShake`, `setFaceDown`) are exposed as fire-and-forget
 * hooks — Android MotionSensor wiring is deferred.
 */
class PersonaController(
    private val scope: CoroutineScope,
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    private val _state = MutableStateFlow(PersonaState.IDLE)
    val state: StateFlow<PersonaState> = _state.asStateFlow()

    private var statsStore: PersonaStatsStore? = null
    private var jobs: MutableList<Job> = mutableListOf()

    private var connected: Boolean = false
    private var running: Int = 0
    private var waiting: Int = 0
    private var recentlyCompleted: Boolean = false

    private var shakeUntilMs: Long? = null
    private var heartUntilMs: Long? = null
    private var celebrateUntilMs: Long? = null
    private var faceDownSinceMs: Long? = null

    fun bind(model: BridgeAppModel, stats: PersonaStatsStore) {
        unbind()
        this.statsStore = stats

        jobs += scope.launch {
            combine(
                model.snapshot,
                model.connectionState,
                model.recentLevelUp,
                model.lastQuickApprovalAt,
            ) { snapshot, connection, leveled, quickApproval ->
                Inputs(snapshot.running, snapshot.waiting, connection, leveled, quickApproval)
            }.collect { inputs ->
                connected = inputs.connection is NusConnectionState.Connected
                running = inputs.running
                waiting = inputs.waiting
                recentlyCompleted = inputs.leveled
                inputs.quickApprovalAt?.let { heartUntilMs = it + HEART_DURATION_MS }
                recompute()
            }
        }

        jobs += scope.launch {
            model.lastCompletedAt.filterNotNull().collect { at ->
                celebrateUntilMs = at + CELEBRATE_DURATION_MS
                recompute()
            }
        }

        // Ticker at 200ms mirrors iOS Timer.publish(every: 0.2) — the only
        // thing it does is advance time-gated overlays past their expiry.
        jobs += scope.launch {
            while (isActive) {
                delay(TICK_PERIOD_MS)
                recompute()
            }
        }
    }

    fun unbind() {
        jobs.forEach { it.cancel() }
        jobs.clear()
    }

    /** Called by motion integrations when a shake gesture is detected. */
    fun notifyShake() {
        shakeUntilMs = clock() + SHAKE_DURATION_MS
        recompute()
    }

    /**
     * Called by motion integrations with the latest face-down signal.
     * Transitioning out of face-down after the sleep delay credits a nap.
     */
    fun setFaceDown(faceDown: Boolean) {
        val now = clock()
        if (faceDown) {
            if (faceDownSinceMs == null) faceDownSinceMs = now
        } else {
            faceDownSinceMs?.let { since ->
                val elapsedMs = now - since
                if (elapsedMs >= FACE_DOWN_SLEEP_DELAY_MS) {
                    statsStore?.onNapEnd(seconds = elapsedMs / 1000.0)
                }
            }
            faceDownSinceMs = null
        }
        recompute()
    }

    private fun recompute() {
        val now = clock()

        shakeUntilMs?.let { until ->
            if (now < until) {
                _state.value = PersonaState.DIZZY
                return
            }
            shakeUntilMs = null
        }

        heartUntilMs?.let { until ->
            if (now < until) {
                _state.value = PersonaState.HEART
                return
            }
            heartUntilMs = null
        }

        faceDownSinceMs?.let { since ->
            if (now - since >= FACE_DOWN_SLEEP_DELAY_MS) {
                _state.value = PersonaState.SLEEP
                return
            }
        }

        celebrateUntilMs?.let { until ->
            if (now < until) {
                _state.value = PersonaState.CELEBRATE
                return
            }
            celebrateUntilMs = null
        }

        _state.value = when {
            recentlyCompleted -> PersonaState.CELEBRATE
            !connected -> PersonaState.IDLE
            waiting > 0 -> PersonaState.ATTENTION
            running >= 1 -> PersonaState.BUSY
            else -> PersonaState.IDLE
        }
    }

    private data class Inputs(
        val running: Int,
        val waiting: Int,
        val connection: NusConnectionState,
        val leveled: Boolean,
        val quickApprovalAt: Long?,
    )

    companion object {
        const val SHAKE_DURATION_MS: Long = 2_000L
        const val HEART_DURATION_MS: Long = 2_000L
        const val CELEBRATE_DURATION_MS: Long = 3_000L
        const val FACE_DOWN_SLEEP_DELAY_MS: Long = 3_000L
        const val TICK_PERIOD_MS: Long = 200L
    }
}
