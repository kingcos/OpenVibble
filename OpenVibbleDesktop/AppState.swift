import Foundation
import Combine
import CoreBluetooth
import BuddyProtocol
import BuddyPersona
import NUSCentral
import HookBridge
import Security

struct StatusAckSnapshot: Equatable {
    var batteryPct: Int?
    var batteryUsb: Bool?
    var batteryVoltageMv: Int?
    var statsLevel: Int?
    var statsApproved: Int?
    var statsVelocitySec: Int?
    var sysFirmware: String?
    var sysUptimeSec: Int?
    var xferRx: Int?
    var xferTx: Int?
    var rawJson: String?
}

@MainActor
final class AppState: ObservableObject {
    @Published var connection: CentralConnectionState = .unknown
    @Published var bluetoothNote: String = "Bluetooth state unknown"
    @Published var bluetoothPowerState: CBManagerState = .unknown
    @Published var discovered: [DiscoveredPeripheral] = []
    @Published var diagnostics: [String] = []
    @Published var connectedName: String?

    @Published var heartbeat: HeartbeatSnapshot?
    @Published var lastAck: BridgeAck?
    @Published var lastTurn: TurnEvent?
    @Published var lastTimeSync: TimeSync?
    @Published var statusSnapshot: StatusAckSnapshot = StatusAckSnapshot()
    @Published var activityLog: [String] = []

    @Published var installProgress: InstallProgress?
    @Published var installRunning: Bool = false
    @Published var installError: String?

    @Published var pendingApproval: PendingApprovalState?
    @Published var hookActivity = HookActivityLog(capacity: 50)
    @Published var registrationStatus: HookRegistrationStatus = .notRegistered
    @Published var bridgeReady: Bool = false
    @Published var bridgePort: UInt16?

    struct PendingApprovalState: Equatable, Identifiable {
        let id: UUID
        let projectName: String?
        let toolName: String?
        let hint: String?
        let payload: PreToolUsePayload

        static func == (lhs: PendingApprovalState, rhs: PendingApprovalState) -> Bool {
            lhs.id == rhs.id
                && lhs.projectName == rhs.projectName
                && lhs.toolName == rhs.toolName
                && lhs.hint == rhs.hint
        }
    }

    let central = BuddyCentralService()
    lazy var installer: CharacterInstaller = CharacterInstaller(central: central)

    private var cancellables: Set<AnyCancellable> = []

    private let registrar = HookRegistrar(
        settingsURL: HookRegistrar.defaultSettingsURL(),
        portFilePath: "$HOME/.claude/openvibble.port"
    )
    private let portFileStore = PortFileStore(url: PortFileStore.defaultURL())
    private var bridgeServer: HookBridgeServer?
    private var bridgeStartTask: Task<Void, Never>?

    init() {
        central.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connection)
        central.$bluetoothStateNote
            .receive(on: DispatchQueue.main)
            .assign(to: &$bluetoothNote)
        central.$bluetoothPowerState
            .receive(on: DispatchQueue.main)
            .assign(to: &$bluetoothPowerState)
        central.$discovered
            .receive(on: DispatchQueue.main)
            .assign(to: &$discovered)
        central.$diagnostics
            .receive(on: DispatchQueue.main)
            .assign(to: &$diagnostics)
        central.$connectedPeripheralName
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectedName)

        central.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.ingest(message)
            }
        }

        installer.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: &$installProgress)
        installer.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$installRunning)
        installer.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$installError)

        refreshRegistrationStatus()
        startBridge()
    }

    deinit { bridgeStartTask?.cancel() }

    func startScan() {
        central.requestAuthorization()
        central.startScan()
        appendLog("[scan] started")
    }

    func stopScan() {
        central.stopScan()
        appendLog("[scan] stopped")
    }

    func connect(_ peripheral: DiscoveredPeripheral) {
        central.connect(id: peripheral.id)
        appendLog("[connect] \(peripheral.name) \(peripheral.id)")
    }

    func disconnect() {
        central.disconnect()
        appendLog("[disconnect] requested")
    }

    func sendStatus() {
        let ok = central.sendEncodable(StatusCommand())
        appendLog(ok ? "[send] cmd:status" : "[send] cmd:status FAILED")
    }

    func sendName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendLog("[send] cmd:name skipped (empty)")
            return
        }
        let ok = central.sendEncodable(NameCommand(name: trimmed))
        appendLog(ok ? "[send] cmd:name \(trimmed)" : "[send] cmd:name FAILED")
    }

    func sendOwner(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            appendLog("[send] cmd:owner skipped (empty)")
            return
        }
        let ok = central.sendEncodable(OwnerCommand(name: trimmed))
        appendLog(ok ? "[send] cmd:owner \(trimmed)" : "[send] cmd:owner FAILED")
    }

    func sendUnpair() {
        let ok = central.sendEncodable(UnpairCommand())
        appendLog(ok ? "[send] cmd:unpair" : "[send] cmd:unpair FAILED")
    }

    func sendSpecies(index: Int) {
        let ok = central.sendEncodable(SpeciesCommand(idx: index))
        let label = PersonaSpeciesCatalog.name(at: index) ?? (index == PersonaSpeciesCatalog.gifSentinel ? "gif" : "idx=\(index)")
        appendLog(ok ? "[send] cmd:species \(label) (idx=\(index))" : "[send] cmd:species FAILED")
    }

    func approveCurrentPrompt() {
        guard let id = heartbeat?.prompt?.id else {
            appendLog("[send] approve skipped (no pending prompt)")
            return
        }
        let ok = central.sendEncodable(PermissionCommand(id: id, decision: .once))
        appendLog(ok ? "[send] approve id=\(id)" : "[send] approve FAILED")
    }

    func denyCurrentPrompt() {
        guard let id = heartbeat?.prompt?.id else {
            appendLog("[send] deny skipped (no pending prompt)")
            return
        }
        let ok = central.sendEncodable(PermissionCommand(id: id, decision: .deny))
        appendLog(ok ? "[send] deny id=\(id)" : "[send] deny FAILED")
    }

    func sendTimeSync() {
        let now = Date()
        let epoch = Int64(now.timeIntervalSince1970)
        let tz = TimeZone.current.secondsFromGMT(for: now)
        let payload = TimeSync(epochSeconds: epoch, timezoneOffsetSeconds: tz)
        let ok = central.sendEncodable(payload)
        appendLog(ok ? "[send] time \(epoch) tz=\(tz)" : "[send] time FAILED")
    }

    func installCharacter(from folder: URL, name: String) {
        Task { @MainActor in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = trimmed.isEmpty ? folder.lastPathComponent : trimmed
            appendLog("[install] begin name=\(finalName) folder=\(folder.lastPathComponent)")
            let result = await installer.install(folder: folder, characterName: finalName)
            switch result {
            case .success:
                appendLog("[install] complete")
            case .failure(let err):
                appendLog("[install] failed: \(err.localizedDescription)")
            }
        }
    }

    func cancelInstall() {
        installer.cancel()
        appendLog("[install] cancel requested")
    }

    func clearLog() {
        activityLog.removeAll()
    }

    private func ingest(_ message: CentralInboundMessage) {
        switch message {
        case .heartbeat(let snapshot):
            heartbeat = snapshot
            appendLog("[recv] heartbeat total=\(snapshot.total) running=\(snapshot.running) waiting=\(snapshot.waiting)")
        case .turn(let turn):
            lastTurn = turn
            appendLog("[recv] turn role=\(turn.role)")
        case .timeSync(let time):
            lastTimeSync = time
            appendLog("[recv] time epoch=\(time.epochSeconds) tz=\(time.timezoneOffsetSeconds)")
        case .ack(let ack):
            lastAck = ack
            if ack.ack == "status", let payload = ack.data {
                statusSnapshot = parseStatus(payload)
            }
            appendLog("[recv] ack=\(ack.ack) ok=\(ack.ok) err=\(ack.error ?? "-")")
        case .permission(let command):
            appendLog("[recv] permission id=\(command.id) decision=\(command.decision.rawValue)")
            if let pending = pendingApproval, pending.id.uuidString == command.id {
                let kind: HookEvent.PermissionDecisionKind = command.decision == .once ? .allow : .deny
                resolve(pending: pending, decision: kind)
            }
        case .unknown(let raw):
            appendLog("[recv] unknown \(raw.prefix(120))")
        }
    }

    private func parseStatus(_ value: JSONValue) -> StatusAckSnapshot {
        var snapshot = StatusAckSnapshot()
        if let bat = value["bat"] {
            snapshot.batteryPct = bat["pct"]?.intValue
            snapshot.batteryUsb = bat["usb"]?.boolValue
            snapshot.batteryVoltageMv = bat["mv"]?.intValue ?? bat["voltage"]?.intValue
        }
        if let stats = value["stats"] {
            snapshot.statsLevel = stats["lvl"]?.intValue
            snapshot.statsApproved = stats["appr"]?.intValue
            snapshot.statsVelocitySec = stats["vel"]?.intValue
        }
        if let sys = value["sys"] {
            snapshot.sysFirmware = sys["fw"]?.stringValue ?? sys["version"]?.stringValue
            snapshot.sysUptimeSec = sys["up"]?.intValue ?? sys["uptime"]?.intValue
        }
        if let xfer = value["xfer"] {
            snapshot.xferRx = xfer["rx"]?.intValue
            snapshot.xferTx = xfer["tx"]?.intValue
        }
        snapshot.rawJson = prettyPrint(value)
        return snapshot
    }

    private func prettyPrint(_ value: JSONValue) -> String? {
        guard let data = try? JSONEncoder().encode(value),
              let any = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: any, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: pretty, encoding: .utf8)
    }

    private func appendLog(_ line: String) {
        let stamp = DateFormatter.logStamp.string(from: Date())
        activityLog.insert("[\(stamp)] \(line)", at: 0)
        if activityLog.count > 200 {
            activityLog.removeLast(activityLog.count - 200)
        }
    }

    // MARK: - Hook bridge lifecycle

    private func startBridge() {
        let token = Self.generateToken()
        let server = HookBridgeServer(token: token) { [weak self] event, body in
            switch event {
            case .preToolUse:
                let payload = (try? JSONDecoder().decode(PreToolUsePayload.self, from: body)) ?? PreToolUsePayload.empty
                let id = UUID()
                Task { @MainActor [weak self] in
                    self?.pushPending(id: id, payload: payload)
                }
                return .pendingApproval(id: id, payload: payload)
            default:
                Task { @MainActor [weak self] in
                    self?.recordFireAndForget(event: event, body: body)
                }
                return .ignore
            }
        }
        self.bridgeServer = server
        bridgeStartTask = Task { [weak self, portFileStore] in
            do {
                let port = try await server.start()
                let payload = PortFile(
                    port: Int(port),
                    token: token,
                    pid: Int(ProcessInfo.processInfo.processIdentifier),
                    version: 1
                )
                try portFileStore.write(payload)
                await MainActor.run {
                    self?.bridgePort = port
                    self?.bridgeReady = true
                    self?.appendLog("[bridge] listening on 127.0.0.1:\(port)")
                }
            } catch {
                await MainActor.run {
                    self?.appendLog("[bridge] start failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    func stopBridge() {
        bridgeStartTask?.cancel()
        let server = bridgeServer
        let store = portFileStore
        Task {
            await server?.stop()
            try? store.remove()
        }
    }

    // MARK: - Pending approval + fire-and-forget

    private func pushPending(id: UUID, payload: PreToolUsePayload) {
        let project = HookEvent.projectName(fromCwd: payload.cwd)
        let hint = (payload.toolInput?["command"]
            ?? payload.toolInput?["description"]
            ?? payload.toolInput?["file_path"]).map { String($0.prefix(120)) }
        let state = PendingApprovalState(
            id: id,
            projectName: project,
            toolName: payload.toolName,
            hint: hint,
            payload: payload
        )
        self.pendingApproval = state
        appendLog("[hook] PreToolUse \(payload.toolName ?? "?") [\(project ?? "?")]")
        hookActivity.append(HookActivityEntry(
            event: .preToolUse,
            projectName: project,
            toolName: payload.toolName
        ))
        pushPromptToPeripheral(state)
    }

    private func pushPromptToPeripheral(_ pending: PendingApprovalState?) {
        let base = heartbeat
        let promptInfo: HeartbeatPrompt? = pending.map { p in
            let label = p.hint ?? p.toolName ?? "request"
            let hintText = p.projectName.map { "[\($0)] \(label)" } ?? label
            return HeartbeatPrompt(id: p.id.uuidString, tool: p.toolName, hint: hintText)
        }
        let snapshot = HeartbeatSnapshot(
            total: base?.total ?? 0,
            running: base?.running ?? 0,
            waiting: (base?.waiting ?? 0) + (promptInfo == nil ? 0 : 1),
            msg: promptInfo == nil ? "cleared" : "pending",
            entries: base?.entries ?? [],
            tokens: base?.tokens,
            tokensToday: base?.tokensToday,
            prompt: promptInfo,
            completed: false
        )
        _ = central.sendEncodable(snapshot)
    }

    private func recordFireAndForget(event: HookEvent, body: Data) {
        let projectName = Self.extractCwd(from: body).flatMap { HookEvent.projectName(fromCwd: $0) }
        hookActivity.append(HookActivityEntry(event: event, projectName: projectName))
        appendLog("[hook] \(event.rawValue) [\(projectName ?? "?")]")
    }

    private static func extractCwd(from body: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        return obj["cwd"] as? String
    }

    func approvePending() {
        guard let pending = pendingApproval else { return }
        resolve(pending: pending, decision: .allow)
    }

    func denyPending() {
        guard let pending = pendingApproval else { return }
        resolve(pending: pending, decision: .deny)
    }

    private func resolve(pending: PendingApprovalState, decision: HookEvent.PermissionDecisionKind) {
        if let server = bridgeServer {
            Task { await server.resolvePending(id: pending.id, decision: decision) }
        }
        self.pendingApproval = nil
        hookActivity.append(HookActivityEntry(
            event: .preToolUse,
            projectName: pending.projectName,
            toolName: pending.toolName,
            decision: decision
        ))
        pushPromptToPeripheral(nil)
        appendLog("[hook] decide \(decision.rawValue) id=\(pending.id)")
    }

    // MARK: - Registration

    func registerHooks() {
        do {
            try registrar.register()
            refreshRegistrationStatus()
            appendLog("[hook] registered")
        } catch {
            appendLog("[hook] register failed: \(error.localizedDescription)")
        }
    }

    func unregisterHooks() {
        do {
            try registrar.unregister()
            refreshRegistrationStatus()
            appendLog("[hook] unregistered")
        } catch {
            appendLog("[hook] unregister failed: \(error.localizedDescription)")
        }
    }

    func refreshRegistrationStatus() {
        do { registrationStatus = try registrar.status() }
        catch { registrationStatus = .notRegistered }
    }

    var bluetoothStateKey: String {
        switch bluetoothPowerState {
        case .poweredOn: return "desktop.bt.on"
        case .poweredOff: return "desktop.bt.off"
        case .unauthorized: return "desktop.bt.unauth"
        case .unsupported: return "desktop.bt.unsupported"
        case .resetting: return "desktop.bt.resetting"
        case .unknown: return "desktop.bt.unknown"
        @unknown default: return "desktop.bt.unknown"
        }
    }
}

extension PreToolUsePayload {
    static let empty = PreToolUsePayload(
        sessionId: nil, cwd: nil, toolName: nil, toolInput: nil, transcriptPath: nil
    )
}

extension JSONValue {
    subscript(key: String) -> JSONValue? {
        if case let .object(dict) = self { return dict[key] }
        return nil
    }

    var intValue: Int? {
        if case let .number(v) = self { return Int(v) }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }

    var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }
}

private extension DateFormatter {
    static let logStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
