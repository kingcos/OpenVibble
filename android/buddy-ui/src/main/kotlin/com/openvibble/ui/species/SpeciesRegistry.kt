// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaState
import com.openvibble.ui.species.overlays.SpeciesOverlays

object SpeciesRegistry {
    private const val TICKS_PER_BEAT: Int = 5
    private const val DEFAULT_IDX: Int = 4 // cat

    fun stateData(idx: Int, state: PersonaState): SpeciesStateData? {
        val name = PersonaSpeciesCatalog.nameAt(idx) ?: return null
        val base = GeneratedSpecies.all[name]?.get(state) ?: return null
        val overlays = SpeciesOverlays.overlays(name, state)
        return if (overlays.isEmpty()) base
        else base.copy(overlays = overlays)
    }

    fun animation(idx: Int, state: PersonaState): AsciiAnimation {
        val data = stateData(idx, state)
            ?: GeneratedSpecies.all["cat"]?.get(state)
            ?: GeneratedSpecies.all["cat"]?.get(PersonaState.IDLE)
            ?: SpeciesStateData(frames = listOf(listOf(" ")), seq = listOf(0), colorRGB565 = 0xFFFF)
        val poses = data.frames.map { AsciiFrame(it) }
        val sequence = if (data.seq.isEmpty()) listOf(0) else data.seq
        return AsciiAnimation(poses = poses, sequence = sequence, ticksPerBeat = TICKS_PER_BEAT)
    }

    fun defaultIdx(): Int = DEFAULT_IDX
}
