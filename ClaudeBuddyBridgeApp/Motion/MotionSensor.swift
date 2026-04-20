import Foundation
import Combine
import CoreMotion

@MainActor
final class MotionSensor: ObservableObject {
    @Published private(set) var isFaceDown: Bool = false
    let shakeSubject = PassthroughSubject<Void, Never>()

    private let manager = CMMotionManager()
    private var lastShakeAt: Date = .distantPast
    private let shakeMagnitudeThreshold: Double = 0.8
    private let shakeDebounceSeconds: TimeInterval = 1.0
    private let faceDownGravityThreshold: Double = -0.9

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion)
        }
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
    }

    private func process(_ motion: CMDeviceMotion) {
        let newFaceDown = motion.gravity.z < faceDownGravityThreshold
        if newFaceDown != isFaceDown { isFaceDown = newFaceDown }

        let u = motion.userAcceleration
        let mag = (u.x * u.x + u.y * u.y + u.z * u.z).squareRoot()
        if mag > shakeMagnitudeThreshold {
            let now = Date()
            if now.timeIntervalSince(lastShakeAt) > shakeDebounceSeconds {
                lastShakeAt = now
                shakeSubject.send(())
            }
        }
    }
}
