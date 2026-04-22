// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import BuddyProtocol
import NUSCentral

struct InstallProgress: Equatable {
    var characterName: String
    var fileIndex: Int
    var fileCount: Int
    var writtenBytes: Int
    var totalBytes: Int
}

enum InstallerError: LocalizedError {
    case empty
    case cancelled
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .empty: return "No files to install."
        case .cancelled: return "Installation cancelled."
        case .sendFailed(let cmd): return "Failed to send \(cmd) over BLE."
        }
    }
}

@MainActor
final class CharacterInstaller: ObservableObject {
    @Published private(set) var progress: InstallProgress?
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?

    private unowned let central: BuddyCentralService
    private var cancelRequested: Bool = false

    private static let rawChunkSize = 120

    init(central: BuddyCentralService) {
        self.central = central
    }

    func cancel() {
        cancelRequested = true
    }

    func install(folder: URL, characterName: String, interPacketDelay: UInt64 = 12_000_000) async -> Result<Void, InstallerError> {
        guard !isRunning else { return .failure(.sendFailed("busy")) }
        isRunning = true
        cancelRequested = false
        lastError = nil
        defer {
            isRunning = false
            progress = nil
        }

        let files: [(name: String, url: URL, size: Int)]
        do {
            files = try enumerateFlatFiles(in: folder)
        } catch {
            lastError = error.localizedDescription
            return .failure(.sendFailed("enumerate"))
        }

        if files.isEmpty { return .failure(.empty) }

        let total = files.reduce(0) { $0 + $1.size }
        progress = InstallProgress(characterName: characterName, fileIndex: 0, fileCount: files.count, writtenBytes: 0, totalBytes: total)

        guard central.sendEncodable(CharBeginCommand(name: characterName, total: total)) else {
            return .failure(.sendFailed("char_begin"))
        }
        try? await Task.sleep(nanoseconds: interPacketDelay)

        for (index, file) in files.enumerated() {
            if cancelRequested { return .failure(.cancelled) }

            progress?.fileIndex = index + 1

            guard central.sendEncodable(FileCommand(path: file.name, size: file.size)) else {
                return .failure(.sendFailed("file"))
            }
            try? await Task.sleep(nanoseconds: interPacketDelay)

            guard let handle = try? FileHandle(forReadingFrom: file.url) else {
                return .failure(.sendFailed("open file"))
            }
            defer { try? handle.close() }

            var sent = 0
            while sent < file.size {
                if cancelRequested { return .failure(.cancelled) }
                let remaining = file.size - sent
                let chunkSize = min(Self.rawChunkSize, remaining)
                guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                    return .failure(.sendFailed("read"))
                }
                let base64 = chunk.base64EncodedString()
                guard central.sendEncodable(ChunkCommand(base64: base64)) else {
                    return .failure(.sendFailed("chunk"))
                }
                sent += chunk.count
                progress?.writtenBytes += chunk.count
                try? await Task.sleep(nanoseconds: interPacketDelay)
            }

            guard central.sendEncodable(FileEndCommand()) else {
                return .failure(.sendFailed("file_end"))
            }
            try? await Task.sleep(nanoseconds: interPacketDelay)
        }

        if cancelRequested { return .failure(.cancelled) }

        guard central.sendEncodable(CharEndCommand()) else {
            return .failure(.sendFailed("char_end"))
        }
        return .success(())
    }

    private func enumerateFlatFiles(in folder: URL) throws -> [(name: String, url: URL, size: Int)] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles])
        var result: [(String, URL, Int)] = []
        for url in contents {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { continue }
            let name = url.lastPathComponent
            if !isValidFlatName(name) { continue }
            let size = values.fileSize ?? 0
            result.append((name, url, size))
        }
        return result.sorted { $0.0 < $1.0 }
    }

    private func isValidFlatName(_ name: String) -> Bool {
        if name.isEmpty { return false }
        if name.contains("/") { return false }
        if name.contains("..") { return false }
        if name.hasPrefix(".") { return false }
        return true
    }
}

