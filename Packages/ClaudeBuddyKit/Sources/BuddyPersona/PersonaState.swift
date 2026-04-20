import Foundation

public enum PersonaState: UInt8, Sendable, CaseIterable {
    case sleep
    case idle
    case busy
    case attention
    case celebrate
    case dizzy
    case heart

    public var slug: String {
        switch self {
        case .sleep: return "sleep"
        case .idle: return "idle"
        case .busy: return "busy"
        case .attention: return "attention"
        case .celebrate: return "celebrate"
        case .dizzy: return "dizzy"
        case .heart: return "heart"
        }
    }
}

public struct PersonaDeriveInput: Sendable, Equatable {
    public let connected: Bool
    public let sessionsRunning: Int
    public let sessionsWaiting: Int
    public let recentlyCompleted: Bool

    public init(
        connected: Bool,
        sessionsRunning: Int,
        sessionsWaiting: Int,
        recentlyCompleted: Bool
    ) {
        self.connected = connected
        self.sessionsRunning = sessionsRunning
        self.sessionsWaiting = sessionsWaiting
        self.recentlyCompleted = recentlyCompleted
    }
}

public enum PersonaOverlay: Sendable, Equatable {
    case none
    case sleep(since: Date)
    case dizzy(until: Date)
    case heart(until: Date)
    case celebrate(until: Date)
}

public func derivePersonaState(_ input: PersonaDeriveInput) -> PersonaState {
    if input.recentlyCompleted { return .celebrate }
    if !input.connected { return .idle }
    if input.sessionsWaiting > 0 { return .attention }
    if input.sessionsRunning >= 3 { return .busy }
    if input.sessionsRunning >= 1 { return .busy }
    return .idle
}

public func resolvePersonaState(
    base: PersonaState,
    overlay: PersonaOverlay,
    now: Date
) -> PersonaState {
    switch overlay {
    case .dizzy(let until) where now < until:
        return .dizzy
    case .heart(let until) where now < until:
        return .heart
    case .sleep(let since) where now.timeIntervalSince(since) >= 3:
        return .sleep
    case .celebrate(let until) where now < until:
        return .celebrate
    default:
        return base
    }
}
