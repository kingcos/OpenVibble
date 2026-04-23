// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.settings

import android.content.Context
import android.content.SharedPreferences

/**
 * Lightweight settings facade backed by a single [SharedPreferences] instance.
 * Mirrors the iOS `@AppStorage` keys used in
 * `OpenVibbleApp.swift`/`SettingsScreen.swift` so parity is obvious:
 *   - `buddy.hasOnboarded` / `buddy.notificationsEnabled`
 * LiveActivity-related keys are intentionally omitted — Android has no parity
 * for ActivityKit and the feature is out of scope for this port.
 */
class AppSettings(private val prefs: SharedPreferences) {

    constructor(context: Context) : this(
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE),
    )

    var hasOnboarded: Boolean
        get() = prefs.getBoolean(KEY_HAS_ONBOARDED, false)
        set(value) { prefs.edit().putBoolean(KEY_HAS_ONBOARDED, value).apply() }

    var notificationsEnabled: Boolean
        get() = prefs.getBoolean(KEY_NOTIFICATIONS_ENABLED, true)
        set(value) { prefs.edit().putBoolean(KEY_NOTIFICATIONS_ENABLED, value).apply() }

    var foregroundNotificationsEnabled: Boolean
        get() = prefs.getBoolean(KEY_FOREGROUND_NOTIFICATIONS_ENABLED, true)
        set(value) { prefs.edit().putBoolean(KEY_FOREGROUND_NOTIFICATIONS_ENABLED, value).apply() }

    var showPowerButton: Boolean
        get() = prefs.getBoolean(KEY_SHOW_POWER_BUTTON, true)
        set(value) { prefs.edit().putBoolean(KEY_SHOW_POWER_BUTTON, value).apply() }

    /** Clear all keys this facade owns; used by the settings "factory reset". */
    fun clearAll() {
        prefs.edit()
            .remove(KEY_HAS_ONBOARDED)
            .remove(KEY_NOTIFICATIONS_ENABLED)
            .remove(KEY_FOREGROUND_NOTIFICATIONS_ENABLED)
            .remove(KEY_SHOW_POWER_BUTTON)
            .apply()
    }

    companion object {
        const val PREFS_NAME: String = SharedPreferencesPersonaSelectionStore.PREFS_NAME
        const val KEY_HAS_ONBOARDED: String = "buddy.hasOnboarded"
        const val KEY_NOTIFICATIONS_ENABLED: String = "buddy.notificationsEnabled"
        const val KEY_FOREGROUND_NOTIFICATIONS_ENABLED: String = "buddy.foregroundNotificationsEnabled"
        const val KEY_SHOW_POWER_BUTTON: String = "home.showPowerButton"
    }
}
