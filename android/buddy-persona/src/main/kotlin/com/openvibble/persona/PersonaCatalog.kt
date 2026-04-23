// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import java.io.File

data class InstalledPersona(
    val name: String,
    val directory: File,
    val manifest: PersonaManifest,
) {
    val id: String get() = name

    fun fileFor(slug: String): List<File> =
        manifest.framesFor(slug)?.filenames?.map { File(directory, it) } ?: emptyList()
}

/**
 * Lists and loads persona packs from a character directory. iOS reads two
 * sources (app bundle "BuiltinCharacters" + app support "characters"); this
 * port accepts arbitrary roots so the `app` module can wire app-specific
 * filesystem locations.
 */
class PersonaCatalog(val rootDirectory: File) {

    fun listInstalled(): List<InstalledPersona> {
        if (!rootDirectory.isDirectory) return emptyList()
        return rootDirectory.listFiles()
            ?.asSequence()
            ?.filter { it.isDirectory && !it.name.startsWith(".") }
            ?.mapNotNull { folder -> load(folder) }
            ?.sortedBy { it.name }
            ?.toList()
            .orEmpty()
    }

    fun load(name: String): InstalledPersona? =
        load(File(rootDirectory, name))

    fun deleteAll(): Boolean {
        if (!rootDirectory.exists()) return true
        return rootDirectory.deleteRecursively()
    }

    companion object {
        const val BUILTIN_DIRECTORY_NAME: String = "BuiltinCharacters"

        fun load(folder: File): InstalledPersona? {
            val manifestFile = File(folder, "manifest.json")
            if (!manifestFile.isFile) return null
            val text = runCatching { manifestFile.readText(Charsets.UTF_8) }.getOrNull() ?: return null
            val manifest = PersonaManifest.fromJson(text) ?: return null
            return InstalledPersona(name = folder.name, directory = folder, manifest = manifest)
        }
    }
}
