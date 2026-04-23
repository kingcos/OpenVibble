// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.persona

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

/**
 * Exercises the copy/idempotency contract on [BuiltinAssetsBootstrapper] with a
 * [FileBuiltinAssetSource] so no `AssetManager` instrumentation is required.
 * The production `AssetManagerBuiltinSource` is a thin pass-through and is
 * exercised end-to-end on-device.
 */
class BuiltinAssetsBootstrapperTest {

    private lateinit var srcRoot: File
    private lateinit var destRoot: File

    @Before fun setUp() {
        srcRoot = Files.createTempDirectory("builtin-src").toFile()
        destRoot = Files.createTempDirectory("builtin-dst").toFile()
    }

    @After fun tearDown() {
        srcRoot.deleteRecursively()
        destRoot.deleteRecursively()
    }

    @Test fun copiesEveryFileFromEveryPersona() {
        writeAsset("bufo", "manifest.json", "{}")
        writeAsset("bufo", "idle_0.gif", "gifbytes")
        writeAsset("cat", "manifest.json", "{\"name\":\"cat\"}")

        val written = BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)

        assertTrue("should report bytes copied", written > 0)
        assertEquals("{}", File(destRoot, "bufo/manifest.json").readText())
        assertEquals("gifbytes", File(destRoot, "bufo/idle_0.gif").readText())
        assertEquals("{\"name\":\"cat\"}", File(destRoot, "cat/manifest.json").readText())
    }

    @Test fun secondRunIsIdempotentAndCopiesNothing() {
        writeAsset("bufo", "manifest.json", "{}")
        writeAsset("bufo", "idle_0.gif", "gifbytes")

        BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)
        val secondRun = BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)

        // Second run sees matching file sizes and skips every copy.
        assertEquals(0L, secondRun)
    }

    @Test fun reCopiesWhenSourceSizeChanges() {
        writeAsset("bufo", "manifest.json", "{}")
        BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)

        writeAsset("bufo", "manifest.json", "{\"version\":2}")
        val written = BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)

        assertTrue("changed source size should trigger re-copy", written > 0)
        assertEquals("{\"version\":2}", File(destRoot, "bufo/manifest.json").readText())
    }

    @Test fun emptySourceRootProducesEmptyDest() {
        val written = BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)
        assertEquals(0L, written)
        // Destination root is created even when nothing is copied so catalog
        // loaders can treat it as a valid empty directory.
        assertTrue(destRoot.isDirectory)
    }

    @Test fun hiddenDotDirsAreSkipped() {
        writeAsset(".DS_Store_dir", "junk", "ignore")
        writeAsset("bufo", "manifest.json", "{}")

        BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)

        assertFalse(File(destRoot, ".DS_Store_dir").exists())
        assertTrue(File(destRoot, "bufo/manifest.json").isFile)
    }

    @Test fun personaCatalogCanLoadBootstrappedAssets() {
        writeAsset(
            "bufo", "manifest.json",
            """{"name":"bufo","states":{"idle":"idle_0.gif"}}""",
        )
        writeAsset("bufo", "idle_0.gif", "gifdata")

        BuiltinAssetsBootstrapper.install(FileBuiltinAssetSource(srcRoot), destRoot)

        val personas = PersonaCatalog(destRoot).listInstalled()
        assertEquals(1, personas.size)
        assertEquals("bufo", personas[0].name)
        assertEquals(
            listOf("idle_0.gif"),
            personas[0].fileFor("idle").map { it.name },
        )
    }

    private fun writeAsset(persona: String, file: String, contents: String) {
        val dir = File(srcRoot, persona).apply { mkdirs() }
        File(dir, file).writeText(contents)
    }
}
