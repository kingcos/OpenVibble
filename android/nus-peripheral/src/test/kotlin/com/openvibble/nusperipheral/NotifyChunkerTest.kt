// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.nusperipheral

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotifyChunkerTest {

    @Test fun emptyPayloadAddsNothing() {
        val chunker = NotifyChunker(chunkSize = 10)
        chunker.enqueue(ByteArray(0))
        assertTrue(chunker.isEmpty())
        assertEquals(0, chunker.pendingCount)
    }

    @Test fun payloadSmallerThanChunkSizeProducesOneChunk() {
        val chunker = NotifyChunker(chunkSize = 10)
        val payload = byteArrayOf(1, 2, 3, 4, 5)
        chunker.enqueue(payload)
        assertEquals(1, chunker.pendingCount)
        assertArrayEquals(payload, chunker.peek())
    }

    @Test fun payloadLargerThanChunkSizeSplitsEvenly() {
        val chunker = NotifyChunker(chunkSize = 4)
        val payload = byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
        chunker.enqueue(payload)
        assertEquals(3, chunker.pendingCount)
    }

    @Test fun payloadWithRemainderSplitsIntoChunksAndRemainder() {
        val chunker = NotifyChunker(chunkSize = 4)
        chunker.enqueue(byteArrayOf(1, 2, 3, 4, 5, 6, 7))
        assertEquals(2, chunker.pendingCount)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), chunker.consume())
        assertArrayEquals(byteArrayOf(5, 6, 7), chunker.consume())
        assertTrue(chunker.isEmpty())
    }

    @Test fun consumeOnEmptyReturnsNull() {
        val chunker = NotifyChunker()
        assertNull(chunker.consume())
    }

    @Test fun clearDropsAllPending() {
        val chunker = NotifyChunker(chunkSize = 4)
        chunker.enqueue(byteArrayOf(1, 2, 3, 4, 5, 6, 7, 8))
        chunker.clear()
        assertTrue(chunker.isEmpty())
    }

    @Test fun defaultChunkSizeMatchesIOSPayloadLimit() {
        assertEquals(180, NotifyChunker.DEFAULT_CHUNK_SIZE)
    }

    @Test fun consumeOrderPreserved() {
        val chunker = NotifyChunker(chunkSize = 3)
        chunker.enqueue(byteArrayOf(1, 2, 3))
        chunker.enqueue(byteArrayOf(4, 5, 6))
        chunker.enqueue(byteArrayOf(7))
        assertArrayEquals(byteArrayOf(1, 2, 3), chunker.consume())
        assertArrayEquals(byteArrayOf(4, 5, 6), chunker.consume())
        assertArrayEquals(byteArrayOf(7), chunker.consume())
        assertFalse(chunker.peek() != null)
    }
}
