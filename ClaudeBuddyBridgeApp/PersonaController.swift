import Foundation
import Combine
import BuddyPersona
import BuddyProtocol

@MainActor
final class PersonaController: ObservableObject {
    @Published private(set) var state: PersonaState = .idle

    private var cancellables: Set<AnyCancellable> = []

    func bind(to model: BridgeAppModel) {
        // Re-derive whenever snapshot or connection state changes.
        Publishers.CombineLatest(model.$snapshot, model.$connectionState)
            .map { snapshot, connection in
                let connected: Bool
                if case .connected = connection { connected = true } else { connected = false }
                return PersonaDeriveInput(
                    connected: connected,
                    sessionsRunning: snapshot.running,
                    sessionsWaiting: snapshot.waiting,
                    recentlyCompleted: false
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
