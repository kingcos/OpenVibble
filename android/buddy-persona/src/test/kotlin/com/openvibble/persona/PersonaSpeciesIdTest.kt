// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PersonaSpeciesIdTest {

    @Test
    fun asciiCat_roundTrip() {
        val id = PersonaSpeciesId.AsciiCat
        assertEquals("ascii:cat", id.rawValue)
        assertEquals(id, PersonaSpeciesId.fromRaw("ascii:cat"))
    }

    @Test
    fun asciiSpecies_roundTrip() {
        val id: PersonaSpeciesId = PersonaSpeciesId.AsciiSpecies(4)
        assertEquals("asciiIdx:4", id.rawValue)
        assertEquals(id, PersonaSpeciesId.fromRaw("asciiIdx:4"))
    }

    @Test
    fun asciiSpecies_invalidInt_returnsNull() {
        assertNull(PersonaSpeciesId.fromRaw("asciiIdx:abc"))
    }

    @Test
    fun builtin_roundTrip() {
        val id: PersonaSpeciesId = PersonaSpeciesId.Builtin("bufo")
        assertEquals("builtin:bufo", id.rawValue)
        assertEquals(id, PersonaSpeciesId.fromRaw("builtin:bufo"))
    }

    @Test
    fun installed_emptyName_returnsNull() {
        assertNull(PersonaSpeciesId.fromRaw("installed:"))
    }

    @Test
    fun unknownPrefix_returnsNull() {
        assertNull(PersonaSpeciesId.fromRaw("random:thing"))
    }

    @Test
    fun catalog_catIndexIsFour() {
        assertEquals("cat", PersonaSpeciesCatalog.nameAt(4))
        assertEquals(18, PersonaSpeciesCatalog.count)
        assertEquals(true, PersonaSpeciesCatalog.isValid(0))
        assertEquals(false, PersonaSpeciesCatalog.isValid(-1))
        assertEquals(false, PersonaSpeciesCatalog.isValid(18))
    }
}
