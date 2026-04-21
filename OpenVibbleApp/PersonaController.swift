import Foundation
import Combine
import BuddyPersona
import BuddyProtocol
import BuddyStats

@MainActor
final class PersonaController: ObservableObject {
    @Published private(set) var state: PersonaState = .idle

    private var cancellables: Set<AnyCancellable> = []
    private weak var statsStore: PersonaStatsStore?

    // Latest base inputs captured from the model.
    private var connected: Bool = false
    private var running: Int = 0
    private var waiting: Int = 0
    private var recentlyCompleted: Bool = false

    // Overlays (time-gated).
    private var shakeUntil: Date?
    private var heartUntil: Date?
    private var celebrateUntil: Date?
    private var faceDownSince: Date?

    private let shakeDuration: TimeInterval = 2
    private let heartDuration: TimeInterval = 2
    private let celebrateDuration: TimeInterval = 3
    private let faceDownSleepDelay: TimeInterval = 3

    func bind(to model: BridgeAppModel, motion: MotionSensor, stats: PersonaStatsStore) {
        self.statsStore = stats

        Publishers.CombineLatest4(
            model.$snapshot,
            model.$connectionState,
            model.$recentLevelUp,
            model.$lastQuickApprovalAt
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] snapshot, connection, leveled, quickApproval in
            guard let self else { return }
            if case .connected = connection { self.connected = true } else { self.connected = false }
            self.running = snapshot.running
            self.waiting = snapshot.waiting
            self.recentlyCompleted = leveled
            if let quickApproval {
                self.heartUntil = quickApproval.addingTimeInterval(self.heartDuration)
            }
            self.recompute()
        }
        .store(in: &cancellables)

        // Heartbeat `completed: true` → 3s celebrate overlay. Matches firmware
        // P_CELEBRATE state derivation (data.h / main.cpp) and h5 demo's
        // triggerOneShot("celebrate", 3000).
        model.$lastCompletedAt
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] at in
                guard let self else { return }
                self.celebrateUntil = at.addingTimeInterval(self.celebrateDuration)
                self.recompute()
            }
            .store(in: &cancellables)

        motion.shakeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.shakeUntil = Date().addingTimeInterval(self.shakeDuration)
                self.recompute()
            }
            .store(in: &cancellables)

        motion.$isFaceDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] faceDown in
                guard let self else { return }
                if faceDown {
                    if self.faceDownSince == nil { self.faceDownSince = Date() }
                } else {
                    if let since = self.faceDownSince {
                        let elapsed = Date().timeIntervalSince(since)
                        if elapsed >= self.faceDownSleepDelay {
                            self.statsStore?.onNapEnd(seconds: elapsed)
                        }
                    }
                    self.faceDownSince = nil
                }
                self.recompute()
            }
            .store(in: &cancellables)

        // Ticker at 0.2s: overlay expirations are time-gated, base state is
        // already re-evaluated when inputs change.
        Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    private func recompute() {
        let now = Date()

        if let until = shakeUntil, now < until { state = .dizzy; return }
        if shakeUntil != nil { shakeUntil = nil }

        if let until = heartUntil, now < until { state = .heart; return }
        if heartUntil != nil { heartUntil = nil }

        if let since = faceDownSince, now.timeIntervalSince(since) >= faceDownSleepDelay {
            state = .sleep; return
        }

        if let until = celebrateUntil, now < until { state = .celebrate; return }
        if celebrateUntil != nil { celebrateUntil = nil }

        if recentlyCompleted { state = .celebrate; return }
        if !connected { state = .idle; return }
        if waiting > 0 { state = .attention; return }
        if running >= 1 { state = .busy; return }
        state = .idle
    }
}
