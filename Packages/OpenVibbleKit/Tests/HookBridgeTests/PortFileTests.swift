// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import HookBridge

@Suite("PortFile")
struct PortFileTests {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hookbridge-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func writeAndRead() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("openvibble.port")
        let payload = PortFile(port: 41847, token: "abc123", pid: 42, version: 1)
        try PortFileStore(url: url).write(payload)
        let read = try PortFileStore(url: url).read()
        #expect(read == payload)
    }

    @Test func removeIfExists() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("openvibble.port")
        let store = PortFileStore(url: url)
        try store.write(PortFile(port: 1, token: "t", pid: 2, version: 1))
        try store.remove()
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
        try store.remove()
    }

    @Test func readMissingThrows() {
        let dir = tempDir()
        let url = dir.appendingPathComponent("missing.port")
        #expect(throws: Error.self) { try PortFileStore(url: url).read() }
    }

    @Test func filePermissionsAreUserOnly() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("openvibble.port")
        try PortFileStore(url: url).write(PortFile(port: 1, token: "t", pid: 2, version: 1))
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let perms = attrs[.posixPermissions] as? NSNumber
        #expect(perms?.int16Value == 0o600)
    }
}
