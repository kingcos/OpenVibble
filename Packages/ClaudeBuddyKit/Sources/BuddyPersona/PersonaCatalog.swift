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
            .appendingPathComponent("ClaudeBuddyBridge", isDirectory: true)
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
                let manifestURL = folder.appendingPathComponent("manifest.json", isDirectory: false)
                guard let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? JSONDecoder().decode(PersonaManifest.self, from: data)
                else { return nil }
                let name = folder.lastPathComponent
                return InstalledPersona(name: name, directory: folder, manifest: manifest)
            }
            .sorted { $0.name < $1.name }
    }

    public func load(name: String) -> InstalledPersona? {
        let folder = rootURL.appendingPathComponent(name, isDirectory: true)
        let manifestURL = folder.appendingPathComponent("manifest.json", isDirectory: false)
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(PersonaManifest.self, from: data)
        else { return nil }
        return InstalledPersona(name: name, directory: folder, manifest: manifest)
    }
}
