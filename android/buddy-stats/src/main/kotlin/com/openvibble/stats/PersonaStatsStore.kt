// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.stats

import java.util.Calendar
import java.util.TimeZone
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Pluggable persistence seam. Production uses DataStoreStatsStorage, tests
 * use InMemoryStatsStorage so we don't need a full Android runtime.
 */
interface StatsStorage {
    fun loadStats(): PersonaStats?
    fun saveStats(stats: PersonaStats)

    fun loadLastNapEndEpochMs(): Long?
    fun saveLastNapEndEpochMs(epochMs: Long)

    fun loadTokensToday(): Int
    fun saveTokensToday(value: Int)

    fun loadTokensTodayAnchorEpochMs(): Long?
    fun saveTokensTodayAnchorEpochMs(epochMs: Long)

    fun clearAll()
}

class InMemoryStatsStorage : StatsStorage {
    private var stats: PersonaStats? = null
    private var lastNapEnd: Long? = null
    private var tokensToday: Int = 0
    private var anchor: Long? = null

    override fun loadStats(): PersonaStats? = stats
    override fun saveStats(stats: PersonaStats) { this.stats = stats }

    override fun loadLastNapEndEpochMs(): Long? = lastNapEnd
    override fun saveLastNapEndEpochMs(epochMs: Long) { lastNapEnd = epochMs }

    override fun loadTokensToday(): Int = tokensToday
    override fun saveTokensToday(value: Int) { tokensToday = value }

    override fun loadTokensTodayAnchorEpochMs(): Long? = anchor
    override fun saveTokensTodayAnchorEpochMs(epochMs: Long) { anchor = epochMs }

    override fun clearAll() {
        stats = null
        lastNapEnd = null
        tokensToday = 0
        anchor = null
    }
}

fun interface Clock {
    fun nowEpochMs(): Long

    companion object {
        val System: Clock = Clock { java.lang.System.currentTimeMillis() }
    }
}

/**
 * 1:1 port of iOS PersonaStatsStore. Exposes two StateFlows (`stats`,
 * `tokensToday`) and mutating methods that match iOS behavior exactly:
 *
 * - First heartbeat latches the bridge token total without crediting.
 * - Bridge regression resyncs without crediting.
 * - Tokens accrue into a ring — stats persist only on level-up.
 * - Energy tier decays one pip every two wall-clock hours since wake.
 * - tokensToday resets when the calendar day rolls over.
 */
class PersonaStatsStore(
    private val storage: StatsStorage = InMemoryStatsStorage(),
    private val clock: Clock = Clock.System,
    initialNow: Long = clock.nowEpochMs(),
) {
    private val _stats = MutableStateFlow(loadInitialStats())
    val stats: StateFlow<PersonaStats> = _stats.asStateFlow()

    private val _tokensToday = MutableStateFlow(0)
    val tokensToday: StateFlow<Int> = _tokensToday.asStateFlow()

    private var lastBridgeTokens: Long = 0L
    private var tokensSynced: Boolean = false

    private var lastWakeEpochMs: Long = storage.loadLastNapEndEpochMs() ?: initialNow
    private var energyAtWake: Int = 3

    private var tokensTodayAnchor: Long = run {
        val anchor = storage.loadTokensTodayAnchorEpochMs()
        if (anchor != null && isSameDay(anchor, initialNow)) {
            _tokensToday.value = storage.loadTokensToday()
            anchor
        } else {
            initialNow
        }
    }

    private fun loadInitialStats(): PersonaStats {
        var s = storage.loadStats() ?: PersonaStats()
        if (s.tokens == 0L && s.level > 0) {
            s = s.copy(tokens = s.level.toLong() * PersonaStats.TOKENS_PER_LEVEL)
        }
        return s
    }

    private fun save() {
        storage.saveStats(_stats.value)
    }

    fun onApproval(secondsToRespond: Double) {
        val clamped = secondsToRespond.toLong().coerceIn(0L, 65_535L).toInt()
        val current = _stats.value
        val newVelocity = current.velocity.toMutableList().apply {
            if (current.velIdx in indices) this[current.velIdx] = clamped
        }
        val newIdx = (current.velIdx + 1) % PersonaStats.VELOCITY_RING_SIZE
        val newCount = (current.velCount + 1).coerceAtMost(PersonaStats.VELOCITY_RING_SIZE)
        _stats.value = current.copy(
            approvals = (current.approvals + 1).coerceAtMost(UShort.MAX_VALUE.toInt()),
            velocity = newVelocity,
            velIdx = newIdx,
            velCount = newCount,
        )
        save()
    }

    fun onDenial() {
        val current = _stats.value
        _stats.value = current.copy(
            denials = (current.denials + 1).coerceAtMost(UShort.MAX_VALUE.toInt()),
        )
        save()
    }

    /**
     * @return true if this delta crossed a level boundary. The current value
     * also persists on the level-up (matching iOS — non-milestone accrual
     * stays RAM-only to avoid thrashing storage on every heartbeat).
     */
    fun onBridgeTokens(bridgeTotal: Long, now: Long = clock.nowEpochMs()): Boolean {
        val total = bridgeTotal.coerceAtLeast(0L)
        if (!tokensSynced) {
            lastBridgeTokens = total
            tokensSynced = true
            return false
        }
        if (total < lastBridgeTokens) {
            lastBridgeTokens = total
            return false
        }
        val delta = total - lastBridgeTokens
        lastBridgeTokens = total
        if (delta == 0L) return false

        rollTokensTodayIfNeeded(now)
        val newTokensToday = (_tokensToday.value.toLong() + delta).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        _tokensToday.value = newTokensToday
        storage.saveTokensToday(newTokensToday)

        val current = _stats.value
        val levelBefore = (current.tokens / PersonaStats.TOKENS_PER_LEVEL)
            .coerceAtMost(UByte.MAX_VALUE.toLong()).toInt()
        val newTokens = current.tokens + delta
        val levelAfter = (newTokens / PersonaStats.TOKENS_PER_LEVEL)
            .coerceAtMost(UByte.MAX_VALUE.toLong()).toInt()

        return if (levelAfter > levelBefore) {
            _stats.value = current.copy(tokens = newTokens, level = levelAfter)
            save()
            true
        } else {
            _stats.value = current.copy(tokens = newTokens)
            false
        }
    }

    private fun rollTokensTodayIfNeeded(now: Long) {
        if (!isSameDay(tokensTodayAnchor, now)) {
            tokensTodayAnchor = now
            _tokensToday.value = 0
            storage.saveTokensTodayAnchorEpochMs(now)
            storage.saveTokensToday(0)
        }
    }

    fun onNapEnd(seconds: Double, now: Long = clock.nowEpochMs()) {
        val current = _stats.value
        val addSeconds = seconds.toLong().coerceAtLeast(0L)
        _stats.value = current.copy(napSeconds = current.napSeconds + addSeconds)
        lastWakeEpochMs = now
        energyAtWake = 5
        storage.saveLastNapEndEpochMs(now)
        save()
    }

    fun energyTier(now: Long = clock.nowEpochMs()): Int {
        val hoursSince = ((now - lastWakeEpochMs).coerceAtLeast(0L) / 3_600_000L).toInt()
        val e = energyAtWake - (hoursSince / 2)
        return e.coerceIn(0, 5)
    }

    fun reset(now: Long = clock.nowEpochMs()) {
        _stats.value = PersonaStats()
        tokensSynced = false
        lastBridgeTokens = 0L
        _tokensToday.value = 0
        tokensTodayAnchor = now
        storage.clearAll()
    }

    private fun isSameDay(a: Long, b: Long): Boolean {
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.timeInMillis = a
        val yearA = cal.get(Calendar.YEAR)
        val dayA = cal.get(Calendar.DAY_OF_YEAR)
        cal.timeInMillis = b
        return yearA == cal.get(Calendar.YEAR) && dayA == cal.get(Calendar.DAY_OF_YEAR)
    }
}
