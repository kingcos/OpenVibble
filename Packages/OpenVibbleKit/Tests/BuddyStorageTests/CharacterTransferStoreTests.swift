// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import BuddyStorage

struct CharacterTransferStoreTests {
    @Test func rejectsIllegalPathTraversal() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = CharacterTransferStore(rootURL: root)

        _ = store.beginCharacter(name: "pet", totalBytes: 32)
        let ack = store.openFile(path: "../secret.txt", size: 10)

        #expect(ack.ok == false)
        #expect(ack.error == "invalid file path")
    }

    @Test func validatesFileSizeOnFileEnd() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = CharacterTransferStore(rootURL: root)

        _ = store.beginCharacter(name: "pet", totalBytes: 32)
        _ = store.openFile(path: "manifest.json", size: 20)
        _ = store.appendChunk(base64: Data("short".utf8).base64EncodedString())
        let end = store.closeFile()

        #expect(end.ok == false)
        #expect(end.error == "size mismatch")
    }

    @Test func completesSingleFileTransfer() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let store = CharacterTransferStore(rootURL: root)

        let begin = store.beginCharacter(name: "buddy", totalBytes: 5)
        let file = store.openFile(path: "manifest.json", size: 5)
        let chunk = store.appendChunk(base64: Data("hello".utf8).base64EncodedString())
        let fileEnd = store.closeFile()
        let charEnd = store.finishCharacter()

        #expect(begin.ok)
        #expect(file.ok)
        #expect(chunk.ok)
        #expect(fileEnd.ok)
        #expect(charEnd.ok)
        #expect(store.progress.writtenBytes == 5)
    }
}
