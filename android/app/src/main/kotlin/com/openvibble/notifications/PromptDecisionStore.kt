// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.notifications

import android.content.Context
import android.content.SharedPreferences

/**
 * Three-valued decision the user can hand back from a notification action —
 * mirrors iOS `LiveActivitySharedStore.Decision`.
 */
enum class PromptDecision { APPROVE, DENY }

/**
 * Minimal key/value surface the decision store needs. Lets unit tests swap
 * in an in-memory fake without any Android framework pulled in.
 */
interface PromptDecisionPrefs {
    fun getString(key: String, default: String?): String?
    fun putString(key: String, value: String?)
    fun remove(key: String)
}

class SharedPreferencesPromptDecisionPrefs(
    private val prefs: SharedPreferences,
) : PromptDecisionPrefs {
    override fun getString(key: String, default: String?): String? = prefs.getString(key, default)
    override fun putString(key: String, value: String?) {
        prefs.edit().putString(key, value).apply()
    }
    override fun remove(key: String) {
        prefs.edit().remove(key).apply()
    }
}

class InMemoryPromptDecisionPrefs : PromptDecisionPrefs {
    private val map = mutableMapOf<String, String?>()
    override fun getString(key: String, default: String?): String? = map.getOrDefault(key, default)
    override fun putString(key: String, value: String?) { map[key] = value }
    override fun remove(key: String) { map.remove(key) }
}

/**
 * Durable hand-off between the notification-action broadcast receiver and
 * the running app. The receiver may fire while the app is killed, so the
 * record persists until MainActivity drains it on first resume.
 *
 * Encoded as `${promptId}${SEP}${decision}` under one key — writes are
 * atomic from the user's perspective, either the whole decision is there
 * or it isn't.
 */
class PromptDecisionStore(private val prefs: PromptDecisionPrefs) {

    constructor(context: Context) : this(
        SharedPreferencesPromptDecisionPrefs(
            context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE),
        ),
    )

    fun writePendingDecision(promptId: String, decision: PromptDecision) {
        if (promptId.isEmpty()) return
        prefs.putString(KEY_PENDING, "$promptId$SEP${decision.name}")
    }

    /**
     * Returns the stored decision and removes it in one pass. Safe to call
     * on every MainActivity.onResume — a no-op when nothing's pending.
     */
    fun drainPending(): PendingDecision? {
        val raw = prefs.getString(KEY_PENDING, null) ?: return null
        prefs.remove(KEY_PENDING)
        val idx = raw.indexOf(SEP)
        if (idx <= 0 || idx >= raw.length - 1) return null
        val id = raw.substring(0, idx)
        val decision = runCatching {
            PromptDecision.valueOf(raw.substring(idx + 1))
        }.getOrNull() ?: return null
        return PendingDecision(promptId = id, decision = decision)
    }

    data class PendingDecision(val promptId: String, val decision: PromptDecision)

    companion object {
        const val PREFS_NAME: String = "openvibble.notification.decision"
        private const val KEY_PENDING = "pending"

        // Non-printable separator. Prompt ids are opaque strings, so a
        // visible delimiter (`|`, `:`) risks collision; U+0001 is safe.
        private const val SEP = ""
    }
}
