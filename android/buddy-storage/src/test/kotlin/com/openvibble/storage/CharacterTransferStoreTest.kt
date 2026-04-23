// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.storage

import java.io.File
import java.nio.file.Files
import java.util.Base64
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CharacterTransferStoreTest {

    private val root: File = Files.createTempDirectory("openvibble-transfer-${UUID.randomUUID()}").toFile()

    @After
    fun tearDown() {
        root.deleteRecursively()
    }

    @Test
    fun rejectsIllegalPathTraversal() {
        val store = CharacterTransferStore(rootDirectory = root)
        store.beginCharacter("pet", totalBytes = 32)
        val ack = store.openFile(path = "../secret.txt", size = 10)
        assertFalse(ack.ok)
        assertEquals("invalid file path", ack.error)
    }

    @Test
    fun rejectsLeadingDotPath() {
        val store = CharacterTransferStore(rootDirectory = root)
        store.beginCharacter("pet", totalBytes = 32)
        val ack = store.openFile(path = ".hidden", size = 10)
        assertFalse(ack.ok)
        assertEquals("invalid file path", ack.error)
    }

    @Test
    fun validatesFileSizeOnFileEnd() {
        val store = CharacterTransferStore(rootDirectory = root)
        store.beginCharacter("pet", totalBytes = 32)
        store.openFile("manifest.json", size = 20)
        store.appendChunk(Base64.getEncoder().encodeToString("short".toByteArray()))
        val end = store.closeFile()
        assertFalse(end.ok)
        assertEquals("size mismatch", end.error)
    }

    @Test
    fun completesSingleFileTransfer() {
        val store = CharacterTransferStore(rootDirectory = root)
        val begin = store.beginCharacter("buddy", totalBytes = 5)
        val file = store.openFile("manifest.json", size = 5)
        val chunk = store.appendChunk(Base64.getEncoder().encodeToString("hello".toByteArray()))
        val fileEnd = store.closeFile()
        val charEnd = store.finishCharacter()

        assertTrue(begin.ok)
        assertTrue(file.ok)
        assertTrue(chunk.ok)
        assertTrue(fileEnd.ok)
        assertTrue(charEnd.ok)
        assertEquals(5, store.progress.writtenBytes)

        val written = File(File(File(root, "characters"), "buddy"), "manifest.json").readText()
        assertEquals("hello", written)
    }

    @Test
    fun rejectsInvalidBase64Chunk() {
        val store = CharacterTransferStore(rootDirectory = root)
        store.beginCharacter("pet", totalBytes = 4)
        store.openFile("a.bin", size = 4)
        val ack = store.appendChunk("!!!not-base64!!!")
        assertFalse(ack.ok)
        assertEquals("invalid base64", ack.error)
    }

    @Test
    fun chunkBeforeBeginReturnsError() {
        val store = CharacterTransferStore(rootDirectory = root)
        val ack = store.appendChunk(Base64.getEncoder().encodeToString("x".toByteArray()))
        assertFalse(ack.ok)
        assertEquals("transfer not active", ack.error)
    }
}
