import Foundation

public enum PersonaSpeciesID: Sendable, Equatable, Hashable {
    case asciiCat
    case builtin(name: String)
    case installed(name: String)

    public var rawValue: String {
        switch self {
        case .asciiCat: return "ascii:cat"
        case .builtin(let name): return "builtin:\(name)"
        case .installed(let name): return "installed:\(name)"
        }
    }

    public init?(rawValue: String) {
        if rawValue == "ascii:cat" { self = .asciiCat; return }
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
