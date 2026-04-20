import Foundation
import Combine
import BuddyPersona
import BuddyProtocol

@MainActor
final class PersonaController: ObservableObject {
    @Published private(set) var state: PersonaState = .idle

    private var cancellables: Set<AnyCancellable> = []

    func bind(to model: BridgeAppModel) {
        Publishers.CombineLatest3(model.$snapshot, model.$connectionState, model.$recentLevelUp)
            .map { snapshot, connection, leveled in
                let connected: Bool
                if case .connected = connection { connected = true } else { connected = false }
                return PersonaDeriveInput(
                    connected: connected,
                    sessionsRunning: snapshot.running,
                    sessionsWaiting: snapshot.waiting,
                    recentlyCompleted: leveled
                )
            }
            .map(derivePersonaState)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
    }
}
