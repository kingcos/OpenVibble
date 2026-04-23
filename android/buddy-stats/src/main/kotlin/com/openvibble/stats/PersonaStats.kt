// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.stats

import kotlinx.serialization.Serializable

/**
 * Stored persona state. iOS uses fixed-width ints (UInt16/UInt8/UInt32)
 * that map into a single persisted 14-byte record; here we persist via
 * DataStore so plain Int/Long is fine, but we still clamp to the same
 * ranges to keep the derived stats math identical across platforms.
 */
@Serializable
data class PersonaStats(
    val approvals: Int = 0,
    val denials: Int = 0,
    val velocity: List<Int> = List(VELOCITY_RING_SIZE) { 0 },
    val velIdx: Int = 0,
    val velCount: Int = 0,
    val level: Int = 0,
    val tokens: Long = 0L,
    val napSeconds: Long = 0L,
) {
    val derivedLevel: Int
        get() = (tokens / TOKENS_PER_LEVEL).coerceIn(0, UByte.MAX_VALUE.toLong()).toInt()

    /** 0..9 level progress pip. */
    val fedProgress: Int
        get() {
            val partial = tokens % TOKENS_PER_LEVEL
            val perPip = TOKENS_PER_LEVEL / 10
            return (partial / perPip).coerceAtMost(9L).toInt()
        }

    val medianVelocitySeconds: Int
        get() {
            if (velCount <= 0) return 0
            val slice = velocity.take(velCount).sorted()
            return slice[velCount / 2]
        }

    /**
     * 0..4 tier: faster median response = higher, heavy deny rate pulls down.
     * Matches iOS `moodTier` 1:1 including the minimum-sample threshold.
     */
    val moodTier: Int
        get() {
            val vel = medianVelocitySeconds
            var tier = when {
                vel == 0 -> 2
                vel < 15 -> 4
                vel < 30 -> 3
                vel < 60 -> 2
                vel < 120 -> 1
                else -> 0
            }
            if (approvals + denials >= 3) {
                when {
                    denials > approvals -> tier -= 2
                    denials * 2 > approvals -> tier -= 1
                }
            }
            return tier.coerceIn(0, 4)
        }

    companion object {
        const val TOKENS_PER_LEVEL: Long = 50_000L
        const val VELOCITY_RING_SIZE: Int = 8
    }
}
