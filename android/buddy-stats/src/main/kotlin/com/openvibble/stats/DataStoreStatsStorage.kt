// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.stats

import android.content.Context
import android.content.SharedPreferences
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Android persistence backed by a single SharedPreferences file. DataStore
 * would be idiomatic but it's strictly async; the iOS store reads
 * synchronously from UserDefaults in init(), and StatsStorage reflects that
 * shape. SharedPreferences gives us the same synchronous semantics without
 * any new seams.
 */
class SharedPreferencesStatsStorage(
    context: Context,
    fileName: String = "openvibble.stats",
) : StatsStorage {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(fileName, Context.MODE_PRIVATE)

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    override fun loadStats(): PersonaStats? {
        val raw = prefs.getString(KEY_STATS, null) ?: return null
        return runCatching { json.decodeFromString(PersonaStats.serializer(), raw) }.getOrNull()
    }

    override fun saveStats(stats: PersonaStats) {
        prefs.edit().putString(KEY_STATS, json.encodeToString(stats)).apply()
    }

    override fun loadLastNapEndEpochMs(): Long? =
        if (prefs.contains(KEY_LAST_NAP)) prefs.getLong(KEY_LAST_NAP, 0L) else null

    override fun saveLastNapEndEpochMs(epochMs: Long) {
        prefs.edit().putLong(KEY_LAST_NAP, epochMs).apply()
    }

    override fun loadTokensToday(): Int = prefs.getInt(KEY_TOKENS_TODAY, 0)

    override fun saveTokensToday(value: Int) {
        prefs.edit().putInt(KEY_TOKENS_TODAY, value).apply()
    }

    override fun loadTokensTodayAnchorEpochMs(): Long? =
        if (prefs.contains(KEY_TOKENS_TODAY_ANCHOR)) prefs.getLong(KEY_TOKENS_TODAY_ANCHOR, 0L) else null

    override fun saveTokensTodayAnchorEpochMs(epochMs: Long) {
        prefs.edit().putLong(KEY_TOKENS_TODAY_ANCHOR, epochMs).apply()
    }

    override fun clearAll() {
        prefs.edit().clear().apply()
    }

    private companion object {
        // Keep key names stable across releases so persisted stats survive updates.
        const val KEY_STATS = "buddy.stats.v1"
        const val KEY_LAST_NAP = "buddy.stats.lastNapEnd"
        const val KEY_TOKENS_TODAY = "buddy.stats.tokensToday"
        const val KEY_TOKENS_TODAY_ANCHOR = "buddy.stats.tokensTodayAnchor"
    }
}
