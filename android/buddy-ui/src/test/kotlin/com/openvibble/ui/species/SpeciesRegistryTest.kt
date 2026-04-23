// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SpeciesRegistryTest {

    @Test
    fun default_idx_points_at_cat() {
        val idx = SpeciesRegistry.defaultIdx()
        assertEquals("cat", PersonaSpeciesCatalog.nameAt(idx))
    }

    @Test
    fun cat_has_state_data_for_all_persona_states() {
        val idx = PersonaSpeciesCatalog.names.indexOf("cat")
        assertTrue(idx >= 0)
        PersonaState.values().forEach { state ->
            val data = SpeciesRegistry.stateData(idx, state)
            assertNotNull("missing cat state $state", data)
            assertTrue(
                "frames empty for cat $state",
                (data?.frames?.isNotEmpty() == true),
            )
            assertTrue(
                "seq empty for cat $state",
                (data?.seq?.isNotEmpty() == true),
            )
        }
    }

    @Test
    fun state_data_for_invalid_idx_is_null() {
        assertNull(SpeciesRegistry.stateData(-1, PersonaState.IDLE))
        assertNull(SpeciesRegistry.stateData(999, PersonaState.IDLE))
    }

    @Test
    fun animation_falls_back_to_cat_when_idx_unknown() {
        val catIdx = PersonaSpeciesCatalog.names.indexOf("cat")
        val expected = SpeciesRegistry.animation(catIdx, PersonaState.IDLE)
        val fallback = SpeciesRegistry.animation(-1, PersonaState.IDLE)
        assertEquals(expected.ticksPerBeat, fallback.ticksPerBeat)
        assertEquals(expected.sequence, fallback.sequence)
        assertEquals(expected.poses.size, fallback.poses.size)
    }

    @Test
    fun animation_ticks_per_beat_is_five() {
        val catIdx = PersonaSpeciesCatalog.names.indexOf("cat")
        assertEquals(5, SpeciesRegistry.animation(catIdx, PersonaState.IDLE).ticksPerBeat)
    }

    @Test
    fun cat_idle_has_no_overlays_but_other_states_do() {
        val catIdx = PersonaSpeciesCatalog.names.indexOf("cat")
        val idle = SpeciesRegistry.stateData(catIdx, PersonaState.IDLE)
        assertNotNull(idle)
        assertTrue("IDLE should have no overlays", idle!!.overlays.isEmpty())

        listOf(
            PersonaState.SLEEP,
            PersonaState.BUSY,
            PersonaState.ATTENTION,
            PersonaState.CELEBRATE,
            PersonaState.DIZZY,
            PersonaState.HEART,
        ).forEach { state ->
            val data = SpeciesRegistry.stateData(catIdx, state)
            assertNotNull(data)
            assertFalse(
                "expected overlays for cat $state",
                data!!.overlays.isEmpty(),
            )
        }
    }

    @Test
    fun cat_attention_and_celebrate_use_white_body_color() {
        val catIdx = PersonaSpeciesCatalog.names.indexOf("cat")
        assertEquals(0xFFFF, SpeciesRegistry.stateData(catIdx, PersonaState.ATTENTION)?.colorRGB565)
        assertEquals(0xFFFF, SpeciesRegistry.stateData(catIdx, PersonaState.CELEBRATE)?.colorRGB565)
        assertEquals(0xFFFF, SpeciesRegistry.stateData(catIdx, PersonaState.DIZZY)?.colorRGB565)
        assertEquals(0xFFFF, SpeciesRegistry.stateData(catIdx, PersonaState.HEART)?.colorRGB565)
    }

    @Test
    fun cat_base_states_use_warm_body_color() {
        val catIdx = PersonaSpeciesCatalog.names.indexOf("cat")
        assertEquals(0xC2A6, SpeciesRegistry.stateData(catIdx, PersonaState.SLEEP)?.colorRGB565)
        assertEquals(0xC2A6, SpeciesRegistry.stateData(catIdx, PersonaState.IDLE)?.colorRGB565)
        assertEquals(0xC2A6, SpeciesRegistry.stateData(catIdx, PersonaState.BUSY)?.colorRGB565)
    }
}
