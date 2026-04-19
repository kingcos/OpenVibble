import Foundation
import UIKit
import Combine
import BridgeRuntime
import NUSPeripheral
import BuddyProtocol
import BuddyStorage

@MainActor
final class BridgeAppModel: ObservableObject {
    @Published private(set) var snapshot: BridgeSnapshot = .empty
    @Published private(set) var prompt: PromptRequest?
    @Published private(set) var transfer: TransferProgress = .idle
    @Published private(set) var connectionState: NUSConnectionState = .stopped
    @Published private(set) var recentEvents: [String] = []

    private let runtime = BridgeRuntime()
    private let peripheral = BuddyPeripheralService()
    private var cancellables: Set<AnyCancellable> = []
    private var started = false

    init() {
        peripheral.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)

        peripheral.onLineReceived = { [weak self] line in
            guard let self else { return }
            self.recordEvent("接收  \(line)")
            let outbound = self.runtime.ingestLine(line)
            self.refreshFromRuntime()
            for response in outbound {
                self.recordEvent("发送  \(response.trimmingCharacters(in: .whitespacesAndNewlines))")
                _ = self.peripheral.sendLine(response)
            }
        }
    }

    func start(displayName: String? = nil) {
        guard !started else { return }
        let defaultSuffix = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        let defaultName = "Claude-\(defaultSuffix.prefix(8))"
        let displayName = sanitizedDisplayName(displayName) ?? defaultName
        peripheral.start(displayName: displayName)
        recordEvent("系统 广播中：\(displayName)")
        refreshFromRuntime()
        started = true
    }

    func restart(displayName: String? = nil) {
        stop()
        start(displayName: displayName)
    }

    func stop() {
        guard started else { return }
        peripheral.stop()
        recordEvent("系统 BLE 外设已停止")
        started = false
    }

    func respondPermission(_ decision: PermissionDecision) {
        guard let line = runtime.respondPermission(decision) else { return }
        let direction = decision == .once ? "允许" : "拒绝"
        recordEvent("发送  权限\(direction)")
        _ = peripheral.sendLine(line)
    }

    private func refreshFromRuntime() {
        snapshot = runtime.currentSnapshot()
        prompt = runtime.pendingPrompt()
        transfer = runtime.transferProgress()
    }

    private func recordEvent(_ line: String) {
        recentEvents.insert(line, at: 0)
        if recentEvents.count > 120 {
            recentEvents.removeLast(recentEvents.count - 120)
        }
    }

    private func sanitizedDisplayName(_ displayName: String?) -> String? {
        guard let displayName else { return nil }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(24))
    }
}
