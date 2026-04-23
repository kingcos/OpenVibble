// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.nusperipheral

/**
 * Splits outbound TX payloads into ≤ `chunkSize` byte slices and queues them.
 * Pulled out into a pure-Kotlin helper so the chunking semantics (iOS uses a
 * fixed 180-byte slice regardless of negotiated MTU) can be unit-tested
 * without a running BluetoothGattServer.
 */
class NotifyChunker(private val chunkSize: Int = DEFAULT_CHUNK_SIZE) {
    private val queue: ArrayDeque<ByteArray> = ArrayDeque()

    val pendingCount: Int get() = queue.size

    fun isEmpty(): Boolean = queue.isEmpty()

    fun enqueue(payload: ByteArray) {
        if (payload.isEmpty()) return
        var offset = 0
        while (offset < payload.size) {
            val end = minOf(offset + chunkSize, payload.size)
            queue.addLast(payload.copyOfRange(offset, end))
            offset = end
        }
    }

    fun peek(): ByteArray? = queue.firstOrNull()

    fun consume(): ByteArray? = if (queue.isEmpty()) null else queue.removeFirst()

    fun clear() {
        queue.clear()
    }

    companion object {
        /**
         * Matches iOS BuddyPeripheralService chunkSize. Android BLE 4.x has a
         * 20-byte default MTU, but modern Androids (8+) negotiate to at least
         * 185 with recent chips. Claude Desktop sends 247-byte MTU requests,
         * so 180 payload bytes is safely below that.
         */
        const val DEFAULT_CHUNK_SIZE: Int = 180
    }
}
