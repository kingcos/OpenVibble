import Foundation
import UIKit
import Combine
import CoreBluetooth
import BridgeRuntime
import NUSPeripheral
import BuddyProtocol
import BuddyStorage
import BuddyStats

@MainActor
final class BridgeAppModel: ObservableObject {
    @Published private(set) var snapshot: BridgeSnapshot = .empty
    @Published private(set) var prompt: PromptRequest?
    @Published private(set) var transfer: TransferProgress = .idle
    @Published private(set) var connectionState: NUSConnectionState = .stopped
    @Published private(set) var bluetoothStateNote: String = "蓝牙状态未知"
    @Published private(set) var bluetoothPowerState: CBManagerState = .unknown
    @Published private(set) var advertisingNote: String = "未广播"
    @Published private(set) var activeDisplayName: String = "Claude"
    @Published private(set) var diagnosticLogs: [String] = []
    @Published private(set) var recentEvents: [String] = []
    @Published private(set) var lastInstalledCharacter: String?
    @Published private(set) var recentLevelUp: Bool = false
    @Published private(set) var lastQuickApprovalAt: Date?
    /// True once the user has responded to the current prompt but the desktop
    /// has not yet cleared it from the next heartbeat. Used by the prompt
    /// panel to swap the "A approve / B deny" hint for a "SENT" state so
    /// users see immediate feedback instead of the waited-timer ticking on.
    @Published private(set) var responseSent: Bool = false
    /// Mirrors `BuddyPeripheralService.authorizationState` so views can react
    /// to the user granting/denying the BLE permission.
    @Published private(set) var bluetoothAuthorization: CBManagerAuthorization = CBPeripheralManager.authorization

    private let quickApprovalThreshold: TimeInterval = 5
    private let liveActivityManager = BuddyLiveActivityManager()

    let statsStore: PersonaStatsStore

    private let runtime = BridgeRuntime()
    private let peripheral = BuddyPeripheralService()
    private var cancellables: Set<AnyCancellable> = []
    private var started = false
    private var lastPromptId: String?
    private var lastPromptAt: Date?
    private var statusSampleTimer: Timer?

    var charactersRootURL: URL { runtime.charactersRootURL }

    init(statsStore: PersonaStatsStore = PersonaStatsStore()) {
        self.statsStore = statsStore
        runtime.onCharacterInstalled = { [weak self] name in
            Task { @MainActor [weak self] in
                self?.lastInstalledCharacter = name
                self?.recordEvent("系统 已安装宠物：\(name)")
            }
        }

        enableBatteryMonitoring()

        peripheral.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                guard let self else { return }
                Task { [snapshot = self.snapshot, hasPrompt = self.prompt != nil] in
                    await self.liveActivityManager.startOrUpdate(
                        state: state,
                        snapshot: snapshot,
                        hasPrompt: hasPrompt
                    )
                }
            }
            .store(in: &cancellables)

        peripheral.$bluetoothStateNote
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                self?.bluetoothStateNote = note
            }
            .store(in: &cancellables)

        peripheral.$bluetoothPowerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bluetoothPowerState = state
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

        peripheral.$authorizationState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] auth in
                self?.bluetoothAuthorization = auth
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
        Task { [snapshot, prompt] in
            await liveActivityManager.startOrUpdate(state: connectionState, snapshot: snapshot, hasPrompt: prompt != nil)
        }
    }

    /// Called by onboarding to show the Bluetooth permission sheet after an
    /// explicit user tap (no auto-prompt at launch).
    func requestBluetoothAuthorization() {
        peripheral.requestAuthorization()
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
        Task {
            await liveActivityManager.end()
        }
    }

    @discardableResult
    func respondPermission(_ decision: PermissionDecision) -> TimeInterval? {
        guard let line = runtime.respondPermission(decision) else { return nil }
        let direction = decision == .once ? "允许" : "拒绝"
        recordEvent("发送  权限\(direction)")
        _ = peripheral.sendLine(line)

        let elapsed = lastPromptAt.map { Date().timeIntervalSince($0) }
        switch decision {
        case .once:
            statsStore.onApproval(secondsToRespond: elapsed ?? 0)
            if let elapsed, elapsed < quickApprovalThreshold {
                lastQuickApprovalAt = Date()
            }
        case .deny:
            statsStore.onDenial()
        }
        lastPromptAt = nil
        lastPromptId = nil
        responseSent = true
        pushStatusSample()
        return elapsed
    }

    func clearLevelUpFlag() {
        recentLevelUp = false
    }

    private func refreshFromRuntime() {
        let newSnapshot = runtime.currentSnapshot()
        snapshot = newSnapshot
        transfer = runtime.transferProgress()

        let newPrompt = runtime.pendingPrompt()
        if let newPrompt, newPrompt.id != lastPromptId {
            lastPromptId = newPrompt.id
            lastPromptAt = Date()
            responseSent = false
            BuddyNotificationCenter.shared.notifyPromptIfNeeded(
                promptID: newPrompt.id,
                tool: newPrompt.tool,
                enabled: notificationsEnabled
            )
        } else if newPrompt == nil {
            lastPromptAt = nil
            lastPromptId = nil
            responseSent = false
        }
        prompt = newPrompt

        let leveledUp = statsStore.onBridgeTokens(newSnapshot.tokens)
        if leveledUp {
            recentLevelUp = true
            recordEvent("系统 升级！等级 \(statsStore.stats.level)")
            BuddyNotificationCenter.shared.notifyLevelUpIfNeeded(
                level: UInt16(statsStore.stats.level),
                enabled: notificationsEnabled
            )
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.recentLevelUp = false
            }
        }
        pushStatusSample()
        Task {
            await liveActivityManager.startOrUpdate(state: connectionState, snapshot: newSnapshot, hasPrompt: newPrompt != nil)
        }
    }

    private func enableBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.pushStatusSample() }
            .store(in: &cancellables)
        pushStatusSample()
    }

    private func pushStatusSample() {
        let device = UIDevice.current
        let rawLevel = device.batteryLevel
        let percent: Int = rawLevel < 0 ? 100 : Int((rawLevel * 100).rounded())
        let usb = (device.batteryState == .charging || device.batteryState == .full)
        let battery = BatterySample(percent: percent, millivolts: 0, milliamps: 0, usb: usb)
        let s = statsStore.stats
        let stats = StatsSample(
            approvals: Int(s.approvals),
            denials: Int(s.denials),
            velocityMedianSeconds: Int(s.medianVelocitySeconds),
            napSeconds: Int(s.napSeconds),
            level: Int(s.level)
        )
        runtime.updateStatusSample(StatusSample(battery: battery, stats: stats))
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

    private var notificationsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "buddy.notificationsEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "buddy.notificationsEnabled")
    }
}
