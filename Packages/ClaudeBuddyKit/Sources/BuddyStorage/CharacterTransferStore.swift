import Foundation
import BuddyProtocol

public struct TransferProgress: Equatable, Sendable {
    public var isActive: Bool
    public var characterName: String
    public var totalBytes: Int
    public var writtenBytes: Int
    public var currentFile: String

    public static let idle = TransferProgress(isActive: false, characterName: "", totalBytes: 0, writtenBytes: 0, currentFile: "")

    public init(isActive: Bool, characterName: String, totalBytes: Int, writtenBytes: Int, currentFile: String) {
        self.isActive = isActive
        self.characterName = characterName
        self.totalBytes = totalBytes
        self.writtenBytes = writtenBytes
        self.currentFile = currentFile
    }
}

public final class CharacterTransferStore {
    public private(set) var progress: TransferProgress = .idle

    public let rootURL: URL
    public var charactersRootURL: URL { rootURL.appendingPathComponent("characters", isDirectory: true) }
    private let fileManager: FileManager

    private var currentHandle: FileHandle?
    private var currentExpectedSize: Int = 0
    private var currentWrittenSize: Int = 0
    private var currentFileURL: URL?

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        if let rootURL {
            self.rootURL = rootURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.rootURL = appSupport.appendingPathComponent("ClaudeBuddyBridge", isDirectory: true)
        }

        try? fileManager.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    public func beginCharacter(name: String, totalBytes: Int) -> BridgeAck {
        closeOpenFileIfNeeded()

        let sanitizedName = sanitizeName(name)
        let characterDirectory = rootURL.appendingPathComponent("characters", isDirectory: true)
        let targetDirectory = characterDirectory.appendingPathComponent(sanitizedName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        } catch {
            return BridgeAck(ack: "char_begin", ok: false, n: 0, error: "cannot create character directory")
        }

        progress = TransferProgress(isActive: true, characterName: sanitizedName, totalBytes: max(0, totalBytes), writtenBytes: 0, currentFile: "")
        return BridgeAck(ack: "char_begin", ok: true, n: 0)
    }

    public func openFile(path: String, size: Int) -> BridgeAck {
        guard progress.isActive else {
            return BridgeAck(ack: "file", ok: false, n: 0, error: "transfer not active")
        }

        guard isValidFlatFilePath(path) else {
            return BridgeAck(ack: "file", ok: false, n: 0, error: "invalid file path")
        }

        closeOpenFileIfNeeded()

        let fileURL = rootURL
            .appendingPathComponent("characters", isDirectory: true)
            .appendingPathComponent(progress.characterName, isDirectory: true)
            .appendingPathComponent(path, isDirectory: false)

        do {
            try Data().write(to: fileURL, options: .atomic)
            let handle = try FileHandle(forWritingTo: fileURL)
            currentHandle = handle
            currentExpectedSize = max(0, size)
            currentWrittenSize = 0
            currentFileURL = fileURL
            progress.currentFile = path
            return BridgeAck(ack: "file", ok: true, n: 0)
        } catch {
            return BridgeAck(ack: "file", ok: false, n: 0, error: "cannot open file")
        }
    }

    public func appendChunk(base64: String) -> BridgeAck {
        guard progress.isActive else {
            return BridgeAck(ack: "chunk", ok: false, n: progress.writtenBytes, error: "transfer not active")
        }

        guard let handle = currentHandle else {
            return BridgeAck(ack: "chunk", ok: false, n: progress.writtenBytes, error: "file not opened")
        }

        guard let data = Data(base64Encoded: base64) else {
            return BridgeAck(ack: "chunk", ok: false, n: progress.writtenBytes, error: "invalid base64")
        }

        do {
            try handle.write(contentsOf: data)
            currentWrittenSize += data.count
            progress.writtenBytes += data.count
            return BridgeAck(ack: "chunk", ok: true, n: currentWrittenSize)
        } catch {
            return BridgeAck(ack: "chunk", ok: false, n: progress.writtenBytes, error: "write failed")
        }
    }

    public func closeFile() -> BridgeAck {
        guard progress.isActive else {
            return BridgeAck(ack: "file_end", ok: false, n: progress.writtenBytes, error: "transfer not active")
        }

        defer {
            closeOpenFileIfNeeded()
            progress.currentFile = ""
        }

        if currentExpectedSize > 0 && currentWrittenSize != currentExpectedSize {
            return BridgeAck(ack: "file_end", ok: false, n: currentWrittenSize, error: "size mismatch")
        }

        return BridgeAck(ack: "file_end", ok: true, n: currentWrittenSize)
    }

    public func finishCharacter() -> BridgeAck {
        closeOpenFileIfNeeded()
        progress.isActive = false
        progress.currentFile = ""
        return BridgeAck(ack: "char_end", ok: true, n: progress.writtenBytes)
    }

    public func reset() {
        closeOpenFileIfNeeded()
        progress = .idle
    }

    private func closeOpenFileIfNeeded() {
        try? currentHandle?.close()
        currentHandle = nil
        currentExpectedSize = 0
        currentWrittenSize = 0
        currentFileURL = nil
    }

    private func sanitizeName(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "pet" : cleaned
    }

    private func isValidFlatFilePath(_ value: String) -> Bool {
        if value.isEmpty { return false }
        if value.contains("..") { return false }
        if value.contains("/") { return false }
        if value.hasPrefix(".") { return false }
        return true
    }
}
