// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

sealed class PersonaSpeciesId {
    abstract val rawValue: String

    data object AsciiCat : PersonaSpeciesId() {
        override val rawValue: String = "ascii:cat"
    }

    data class AsciiSpecies(val idx: Int) : PersonaSpeciesId() {
        override val rawValue: String get() = "asciiIdx:$idx"
    }

    data class Builtin(val name: String) : PersonaSpeciesId() {
        override val rawValue: String get() = "builtin:$name"
    }

    data class Installed(val name: String) : PersonaSpeciesId() {
        override val rawValue: String get() = "installed:$name"
    }

    companion object {
        fun fromRaw(raw: String): PersonaSpeciesId? = when {
            raw == "ascii:cat" -> AsciiCat
            raw.startsWith("asciiIdx:") ->
                raw.removePrefix("asciiIdx:").toIntOrNull()?.let(::AsciiSpecies)
            raw.startsWith("builtin:") ->
                raw.removePrefix("builtin:").takeIf { it.isNotEmpty() }?.let(::Builtin)
            raw.startsWith("installed:") ->
                raw.removePrefix("installed:").takeIf { it.isNotEmpty() }?.let(::Installed)
            else -> null
        }
    }
}

/** Species list mirroring claude-desktop-buddy firmware (buddy.cpp). */
object PersonaSpeciesCatalog {
    val names: List<String> = listOf(
        "capybara", "duck", "goose", "blob", "cat", "dragon",
        "octopus", "owl", "penguin", "turtle", "snail", "ghost",
        "axolotl", "cactus", "robot", "rabbit", "mushroom", "chonk",
    )

    val count: Int get() = names.size

    /** Sentinel idx used by firmware to request the GIF pipeline. */
    const val GIF_SENTINEL: Int = 0xFF

    fun isValid(idx: Int): Boolean = idx in names.indices

    fun nameAt(idx: Int): String? = names.getOrNull(idx)
}

interface PersonaSelectionStore {
    fun load(): PersonaSpeciesId
    fun save(selection: PersonaSpeciesId)
}

/**
 * Platform-agnostic selection loader. Keys match iOS ("buddy.species.id")
 * so both platforms can share a settings spec if ever synced.
 */
object PersonaSelection {
    const val STORAGE_KEY: String = "buddy.species.id"
    val defaultSpecies: PersonaSpeciesId = PersonaSpeciesId.AsciiCat
}
