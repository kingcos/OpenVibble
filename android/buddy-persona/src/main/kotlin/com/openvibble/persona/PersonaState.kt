// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

enum class PersonaState(val slug: String) {
    SLEEP("sleep"),
    IDLE("idle"),
    BUSY("busy"),
    ATTENTION("attention"),
    CELEBRATE("celebrate"),
    DIZZY("dizzy"),
    HEART("heart");

    companion object {
        fun fromSlug(slug: String): PersonaState? = values().firstOrNull { it.slug == slug }
    }
}

data class PersonaDeriveInput(
    val connected: Boolean,
    val sessionsRunning: Int,
    val sessionsWaiting: Int,
    val recentlyCompleted: Boolean,
)

/** Time-bounded state overrides applied on top of the derived base state. */
sealed class PersonaOverlay {
    data object None : PersonaOverlay()
    data class Sleep(val sinceEpochMs: Long) : PersonaOverlay()
    data class Dizzy(val untilEpochMs: Long) : PersonaOverlay()
    data class Heart(val untilEpochMs: Long) : PersonaOverlay()
    data class Celebrate(val untilEpochMs: Long) : PersonaOverlay()
}

fun derivePersonaState(input: PersonaDeriveInput): PersonaState {
    if (input.recentlyCompleted) return PersonaState.CELEBRATE
    if (!input.connected) return PersonaState.IDLE
    if (input.sessionsWaiting > 0) return PersonaState.ATTENTION
    if (input.sessionsRunning >= 1) return PersonaState.BUSY
    return PersonaState.IDLE
}

fun resolvePersonaState(
    base: PersonaState,
    overlay: PersonaOverlay,
    nowEpochMs: Long,
): PersonaState = when (overlay) {
    is PersonaOverlay.Dizzy -> if (nowEpochMs < overlay.untilEpochMs) PersonaState.DIZZY else base
    is PersonaOverlay.Heart -> if (nowEpochMs < overlay.untilEpochMs) PersonaState.HEART else base
    is PersonaOverlay.Sleep ->
        if (nowEpochMs - overlay.sinceEpochMs >= SLEEP_GRACE_MS) PersonaState.SLEEP else base
    is PersonaOverlay.Celebrate -> if (nowEpochMs < overlay.untilEpochMs) PersonaState.CELEBRATE else base
    PersonaOverlay.None -> base
}

private const val SLEEP_GRACE_MS = 3_000L
