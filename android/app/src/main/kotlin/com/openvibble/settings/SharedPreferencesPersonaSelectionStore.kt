// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.settings

import android.content.Context
import android.content.SharedPreferences
import com.openvibble.persona.PersonaSelection
import com.openvibble.persona.PersonaSelectionStore
import com.openvibble.persona.PersonaSpeciesId

/**
 * Android parity with iOS `UserDefaults`-backed persona selection.
 * The storage key (`buddy.species.id`) and serialisation format (`rawValue`)
 * match iOS exactly so a future sync layer can use either side's payload.
 */
class SharedPreferencesPersonaSelectionStore(
    private val prefs: SharedPreferences,
) : PersonaSelectionStore {

    constructor(context: Context) : this(
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE),
    )

    override fun load(): PersonaSpeciesId {
        val raw = prefs.getString(PersonaSelection.STORAGE_KEY, null) ?: return PersonaSelection.defaultSpecies
        return PersonaSpeciesId.fromRaw(raw) ?: PersonaSelection.defaultSpecies
    }

    override fun save(selection: PersonaSpeciesId) {
        prefs.edit().putString(PersonaSelection.STORAGE_KEY, selection.rawValue).apply()
    }

    companion object {
        const val PREFS_NAME: String = "openvibble.settings"
    }
}
