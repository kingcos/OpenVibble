// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct PortFile: Codable, Equatable, Sendable {
    public var port: Int
    public var token: String
    public var pid: Int
    public var version: Int

    public init(port: Int, token: String, pid: Int, version: Int) {
        self.port = port
        self.token = token
        self.pid = pid
        self.version = version
    }
}

public struct PortFileStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("openvibble.port", isDirectory: false)
    }

    public func write(_ payload: PortFile) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func read() throws -> PortFile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PortFile.self, from: data)
    }

    public func remove() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        try fm.removeItem(at: url)
    }
}
