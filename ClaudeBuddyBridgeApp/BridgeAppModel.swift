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
    @Published private(set) var bluetoothStateNote: String = "蓝牙状态未知"
    @Published private(set) var advertisingNote: String = "未广播"
    @Published private(set) var activeDisplayName: String = "Claude"
    @Published private(set) var diagnosticLogs: [String] = []
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

        peripheral.$bluetoothStateNote
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.bluetoothStateNote = note
            }
            .store(in: &cancellables)

        peripheral.$advertisingNote
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.advertisingNote = note
            }
            .store(in: &cancellables)

        peripheral.$diagnostics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logs in
                self?.diagnosticLogs = logs
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

    func start(displayName: String? = nil, includeServiceUUIDInAdvertisement: Bool = true) {
        guard !started else { return }
        let finalName = resolvedDisplayName(displayName)
        activeDisplayName = finalName
        peripheral.setAdvertisementMode(includeServiceUUID: includeServiceUUIDInAdvertisement)
        peripheral.start(displayName: finalName)
        recordEvent("系统 请求启动广播：\(finalName)")
        refreshFromRuntime()
        started = true
    }

    func restart(displayName: String? = nil, includeServiceUUIDInAdvertisement: Bool = true) {
        stop()
        start(displayName: displayName, includeServiceUUIDInAdvertisement: includeServiceUUIDInAdvertisement)
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
        var trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("claude") {
            trimmed = "Claude-\(trimmed)"
        }
        return String(trimmed.prefix(12))
    }

    private func resolvedDisplayName(_ requested: String?) -> String {
        // Claude Desktop 文档要求以 Claude 开头；这里强制固定成 Claude，
        // 最大化发现兼容性（避免因扩展名长度或过滤规则导致扫不到）。
        _ = sanitizedDisplayName(requested)
        return "Claude"
    }
}
