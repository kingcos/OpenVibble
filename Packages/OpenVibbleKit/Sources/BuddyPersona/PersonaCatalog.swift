// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct InstalledPersona: Sendable, Equatable, Identifiable {
    public var id: String { name }
    public let name: String
    public let directory: URL
    public let manifest: PersonaManifest

    public func fileURL(for slug: String) -> [URL] {
        guard let frames = manifest.frames(for: slug) else { return [] }
        return frames.filenames.map { directory.appendingPathComponent($0, isDirectory: false) }
    }
}

public struct PersonaCatalog {
    public let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            self.rootURL = Self.defaultCharactersRootURL(fileManager: fileManager)
        }
        self.fileManager = fileManager
    }

    public static func defaultCharactersRootURL(fileManager: FileManager = .default) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("OpenVibble", isDirectory: true)
            .appendingPathComponent("characters", isDirectory: true)
    }

    public func listInstalled() -> [InstalledPersona] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries
            .compactMap { folder -> InstalledPersona? in
                guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
                return Self.load(folder: folder)
            }
            .sorted { $0.name < $1.name }
    }

    public func load(name: String) -> InstalledPersona? {
        let folder = rootURL.appendingPathComponent(name, isDirectory: true)
        return Self.load(folder: folder)
    }

    @discardableResult
    public func deleteAll() -> Bool {
        guard fileManager.fileExists(atPath: rootURL.path) else { return true }
        do {
            try fileManager.removeItem(at: rootURL)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Built-in personas (shipped in the app bundle, read-only)

    public static let builtinDirectoryName = "BuiltinCharacters"

    public static func listBuiltin(bundle: Bundle = .main, fileManager: FileManager = .default) -> [InstalledPersona] {
        guard let root = builtinRootURL(bundle: bundle) else { return [] }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries
            .compactMap { folder -> InstalledPersona? in
                guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
                return load(folder: folder)
            }
            .sorted { $0.name < $1.name }
    }

    public static func loadBuiltin(name: String, bundle: Bundle = .main) -> InstalledPersona? {
        guard let root = builtinRootURL(bundle: bundle) else { return nil }
        let folder = root.appendingPathComponent(name, isDirectory: true)
        return load(folder: folder)
    }

    private static func builtinRootURL(bundle: Bundle) -> URL? {
        bundle.url(forResource: builtinDirectoryName, withExtension: nil)
    }

    private static func load(folder: URL) -> InstalledPersona? {
        let manifestURL = folder.appendingPathComponent("manifest.json", isDirectory: false)
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(PersonaManifest.self, from: data)
        else { return nil }
        let name = folder.lastPathComponent
        return InstalledPersona(name: name, directory: folder, manifest: manifest)
    }
}
