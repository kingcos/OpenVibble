import Foundation
import Combine
import BuddyProtocol
import BuddyPersona
import NUSCentral

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

    let central = BuddyCentralService()
    lazy var installer: CharacterInstaller = CharacterInstaller(central: central)

    private var cancellables: Set<AnyCancellable> = []

    init() {
        central.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connection)
        central.$bluetoothStateNote
            .receive(on: DispatchQueue.main)
            .assign(to: &$bluetoothNote)
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
    }

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
