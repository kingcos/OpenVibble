// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.storage

import com.openvibble.protocol.BridgeAck
import java.io.File
import java.io.FileOutputStream
import java.util.Base64

data class TransferProgress(
    val isActive: Boolean,
    val characterName: String,
    val totalBytes: Int,
    val writtenBytes: Int,
    val currentFile: String,
) {
    companion object {
        val idle: TransferProgress = TransferProgress(
            isActive = false,
            characterName = "",
            totalBytes = 0,
            writtenBytes = 0,
            currentFile = "",
        )
    }
}

/**
 * Receives character pack transfers over BLE. Mirrors iOS
 * CharacterTransferStore 1:1 — same path sanitation, same size-mismatch
 * handling on file_end, same ack envelopes.
 */
class CharacterTransferStore(val rootDirectory: File) {

    val charactersRoot: File get() = File(rootDirectory, "characters")

    @Volatile
    var progress: TransferProgress = TransferProgress.idle
        private set

    private var currentStream: FileOutputStream? = null
    private var currentExpectedSize: Int = 0
    private var currentWrittenSize: Int = 0

    init {
        rootDirectory.mkdirs()
    }

    fun beginCharacter(name: String, totalBytes: Int): BridgeAck {
        closeOpenFileIfNeeded()

        val sanitized = sanitizeName(name)
        val targetDirectory = File(charactersRoot, sanitized)
        if (!targetDirectory.exists() && !targetDirectory.mkdirs()) {
            return BridgeAck(ack = "char_begin", ok = false, n = 0, error = "cannot create character directory")
        }

        progress = TransferProgress(
            isActive = true,
            characterName = sanitized,
            totalBytes = totalBytes.coerceAtLeast(0),
            writtenBytes = 0,
            currentFile = "",
        )
        return BridgeAck(ack = "char_begin", ok = true, n = 0)
    }

    fun openFile(path: String, size: Int): BridgeAck {
        if (!progress.isActive) {
            return BridgeAck(ack = "file", ok = false, n = 0, error = "transfer not active")
        }
        if (!isValidFlatFilePath(path)) {
            return BridgeAck(ack = "file", ok = false, n = 0, error = "invalid file path")
        }

        closeOpenFileIfNeeded()

        val target = File(File(charactersRoot, progress.characterName), path)
        return try {
            target.parentFile?.mkdirs()
            currentStream = FileOutputStream(target, /* append = */ false)
            currentExpectedSize = size.coerceAtLeast(0)
            currentWrittenSize = 0
            progress = progress.copy(currentFile = path)
            BridgeAck(ack = "file", ok = true, n = 0)
        } catch (t: Throwable) {
            BridgeAck(ack = "file", ok = false, n = 0, error = "cannot open file")
        }
    }

    fun appendChunk(base64: String): BridgeAck {
        if (!progress.isActive) {
            return BridgeAck(ack = "chunk", ok = false, n = progress.writtenBytes, error = "transfer not active")
        }
        val stream = currentStream
            ?: return BridgeAck(ack = "chunk", ok = false, n = progress.writtenBytes, error = "file not opened")

        val bytes = runCatching { Base64.getDecoder().decode(base64) }.getOrNull()
            ?: return BridgeAck(ack = "chunk", ok = false, n = progress.writtenBytes, error = "invalid base64")

        return try {
            stream.write(bytes)
            currentWrittenSize += bytes.size
            progress = progress.copy(writtenBytes = progress.writtenBytes + bytes.size)
            BridgeAck(ack = "chunk", ok = true, n = currentWrittenSize)
        } catch (t: Throwable) {
            BridgeAck(ack = "chunk", ok = false, n = progress.writtenBytes, error = "write failed")
        }
    }

    fun closeFile(): BridgeAck {
        if (!progress.isActive) {
            return BridgeAck(ack = "file_end", ok = false, n = progress.writtenBytes, error = "transfer not active")
        }

        val written = currentWrittenSize
        val expected = currentExpectedSize
        closeOpenFileIfNeeded()
        progress = progress.copy(currentFile = "")

        if (expected > 0 && written != expected) {
            return BridgeAck(ack = "file_end", ok = false, n = written, error = "size mismatch")
        }
        return BridgeAck(ack = "file_end", ok = true, n = written)
    }

    fun finishCharacter(): BridgeAck {
        closeOpenFileIfNeeded()
        val n = progress.writtenBytes
        progress = progress.copy(isActive = false, currentFile = "")
        return BridgeAck(ack = "char_end", ok = true, n = n)
    }

    fun reset() {
        closeOpenFileIfNeeded()
        progress = TransferProgress.idle
    }

    private fun closeOpenFileIfNeeded() {
        runCatching { currentStream?.close() }
        currentStream = null
        currentExpectedSize = 0
        currentWrittenSize = 0
    }

    private fun sanitizeName(value: String): String {
        val cleaned = value
            .replace("..", "")
            .replace("/", "-")
            .trim()
        return cleaned.ifEmpty { "pet" }
    }

    private fun isValidFlatFilePath(value: String): Boolean =
        value.isNotEmpty() &&
            !value.contains("..") &&
            !value.contains('/') &&
            !value.startsWith(".")
}
