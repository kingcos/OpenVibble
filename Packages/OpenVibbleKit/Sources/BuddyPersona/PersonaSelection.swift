import Foundation

public enum PersonaSpeciesID: Sendable, Equatable, Hashable {
    case asciiCat
    case asciiSpecies(idx: Int)
    case builtin(name: String)
    case installed(name: String)

    public var rawValue: String {
        switch self {
        case .asciiCat: return "ascii:cat"
        case .asciiSpecies(let idx): return "asciiIdx:\(idx)"
        case .builtin(let name): return "builtin:\(name)"
        case .installed(let name): return "installed:\(name)"
        }
    }

    public init?(rawValue: String) {
        if rawValue == "ascii:cat" { self = .asciiCat; return }
        if rawValue.hasPrefix("asciiIdx:") {
            let raw = String(rawValue.dropFirst("asciiIdx:".count))
            guard let idx = Int(raw) else { return nil }
            self = .asciiSpecies(idx: idx); return
        }
        if rawValue.hasPrefix("builtin:") {
            let name = String(rawValue.dropFirst("builtin:".count))
            if name.isEmpty { return nil }
            self = .builtin(name: name); return
        }
        if rawValue.hasPrefix("installed:") {
            let name = String(rawValue.dropFirst("installed:".count))
            if name.isEmpty { return nil }
            self = .installed(name: name); return
        }
        return nil
    }
}

public enum PersonaSpeciesCatalog {
    /// Species index list mirroring claude-desktop-buddy firmware (buddy.cpp).
    /// Index 4 = "cat" — currently the only species with full ASCII frames on iOS.
    public static let names: [String] = [
        "capybara", "duck", "goose", "blob", "cat", "dragon",
        "octopus", "owl", "penguin", "turtle", "snail", "ghost",
        "axolotl", "cactus", "robot", "rabbit", "mushroom", "chonk"
    ]

    public static let count = names.count
    public static let gifSentinel = 0xFF

    public static func isValid(idx: Int) -> Bool {
        idx >= 0 && idx < count
    }

    public static func name(at idx: Int) -> String? {
        guard isValid(idx: idx) else { return nil }
        return names[idx]
    }
}

public struct PersonaSelection: Sendable {
    public static let storageKey = "buddy.species.id"
    public static let defaultSpecies: PersonaSpeciesID = .asciiCat

    public static func load(defaults: UserDefaults = .standard) -> PersonaSpeciesID {
        guard let raw = defaults.string(forKey: storageKey),
              let parsed = PersonaSpeciesID(rawValue: raw)
        else { return defaultSpecies }
        return parsed
    }

    public static func save(_ selection: PersonaSpeciesID, defaults: UserDefaults = .standard) {
        defaults.set(selection.rawValue, forKey: storageKey)
    }
}
