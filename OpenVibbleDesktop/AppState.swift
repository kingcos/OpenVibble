import Foundation
import Combine
import BuddyProtocol
import NUSCentral

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
    @Published var activityLog: [String] = []

    let central = BuddyCentralService()

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
        let ok = central.sendEncodable(NameCommand(name: name))
        appendLog(ok ? "[send] cmd:name \(name)" : "[send] cmd:name FAILED")
    }

    func sendOwner(_ name: String) {
        let ok = central.sendEncodable(OwnerCommand(name: name))
        appendLog(ok ? "[send] cmd:owner \(name)" : "[send] cmd:owner FAILED")
    }

    func sendUnpair() {
        let ok = central.sendEncodable(UnpairCommand())
        appendLog(ok ? "[send] cmd:unpair" : "[send] cmd:unpair FAILED")
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
            appendLog("[recv] ack=\(ack.ack) ok=\(ack.ok) err=\(ack.error ?? "-")")
        case .unknown(let raw):
            appendLog("[recv] unknown \(raw.prefix(120))")
        }
    }

    private func appendLog(_ line: String) {
        let stamp = DateFormatter.logStamp.string(from: Date())
        activityLog.insert("[\(stamp)] \(line)", at: 0)
        if activityLog.count > 200 {
            activityLog.removeLast(activityLog.count - 200)
        }
    }
}

private extension DateFormatter {
    static let logStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
