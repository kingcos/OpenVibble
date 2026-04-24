// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import android.content.res.AssetManager
import java.io.File
import java.io.IOException
import java.io.InputStream

/**
 * Android parity with the iOS app bundle's `BuiltinCharacters` directory.
 *
 * iOS reads the built-in GIF packs straight out of the app bundle, but our
 * [com.openvibble.persona.PersonaCatalog] loader works off real `java.io.File`
 * paths (so Coil's `ImageDecoderDecoder` can seek the GIF frames). Android
 * assets aren't normal files, so on first launch we stream each pack out of
 * `assets/BuiltinCharacters/<persona>` into `filesDir/builtin-characters/<persona>`.
 *
 * The source/destination split keeps the copy logic testable on the host JVM
 * without an [AssetManager] — tests inject a [FileBuiltinAssetSource] backed
 * by a `java.nio` temp directory.
 */
interface BuiltinAssetSource {
    /** Persona directory names inside the source root (e.g. `bufo`). */
    fun listPersonas(): List<String>

    /** Relative file names inside a persona directory (e.g. `manifest.json`, `idle_0.gif`). */
    fun listFiles(persona: String): List<String>

    /** Opens a source file for reading. Callers must close the stream. */
    fun open(persona: String, file: String): InputStream

    /** Returns the source file size in bytes if known, or null to force-copy. */
    fun sizeOf(persona: String, file: String): Long?
}

/** [BuiltinAssetSource] backed by [AssetManager] — production implementation. */
class AssetManagerBuiltinSource(
    private val assets: AssetManager,
    private val rootDirectory: String = PersonaCatalog.BUILTIN_DIRECTORY_NAME,
) : BuiltinAssetSource {

    override fun listPersonas(): List<String> =
        runCatching { assets.list(rootDirectory) }.getOrNull()?.toList().orEmpty()

    override fun listFiles(persona: String): List<String> =
        runCatching { assets.list("$rootDirectory/$persona") }.getOrNull()?.toList().orEmpty()

    override fun open(persona: String, file: String): InputStream =
        assets.open("$rootDirectory/$persona/$file")

    override fun sizeOf(persona: String, file: String): Long? = null // AssetManager has no cheap size API
}

/** [BuiltinAssetSource] backed by a real directory — convenient for unit tests. */
class FileBuiltinAssetSource(private val sourceRoot: File) : BuiltinAssetSource {

    override fun listPersonas(): List<String> =
        sourceRoot.listFiles { f -> f.isDirectory && !f.name.startsWith(".") }
            ?.map { it.name }?.sorted().orEmpty()

    override fun listFiles(persona: String): List<String> =
        File(sourceRoot, persona).listFiles { f -> f.isFile && !f.name.startsWith(".") }
            ?.map { it.name }?.sorted().orEmpty()

    override fun open(persona: String, file: String): InputStream =
        File(sourceRoot, "$persona/$file").inputStream()

    override fun sizeOf(persona: String, file: String): Long? =
        File(sourceRoot, "$persona/$file").takeIf { it.isFile }?.length()
}

object BuiltinAssetsBootstrapper {

    /**
     * Streams each persona file from [source] into [destRoot], skipping files
     * whose destination already matches the source size. Returns the number of
     * bytes actually written so tests can assert idempotency.
     *
     * Failures on an individual file are swallowed so a single bad asset can't
     * block the other built-in packs — Persona loading already tolerates a
     * missing manifest entry.
     */
    fun install(source: BuiltinAssetSource, destRoot: File): Long {
        destRoot.mkdirs()
        var written = 0L
        for (persona in source.listPersonas()) {
            val personaDir = File(destRoot, persona).apply { mkdirs() }
            for (file in source.listFiles(persona)) {
                val destFile = File(personaDir, file)
                val srcSize = source.sizeOf(persona, file)
                if (srcSize != null && destFile.isFile && destFile.length() == srcSize) continue
                runCatching {
                    source.open(persona, file).use { input ->
                        destFile.outputStream().use { out -> input.copyTo(out) }
                    }
                    written += destFile.length()
                }.onFailure { err ->
                    // Clean up partially written file so the next run retries.
                    if (err is IOException) destFile.delete()
                }
            }
        }
        return written
    }
}
