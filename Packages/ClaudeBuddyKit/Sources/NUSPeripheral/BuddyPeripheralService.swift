import Foundation
@preconcurrency import CoreBluetooth
import Combine
import BuddyProtocol

public enum NUSConnectionState: Equatable, Sendable {
    case stopped
    case advertising
    case connected(centralCount: Int)
}

public enum NUSUUIDs {
    public static let serviceString = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    public static let rxString = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    public static let txString = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

    static var service: CBUUID { CBUUID(string: serviceString) }
    static var rx: CBUUID { CBUUID(string: rxString) }
    static var tx: CBUUID { CBUUID(string: txString) }
}

public final class BuddyPeripheralService: NSObject, ObservableObject {
    @Published public private(set) var connectionState: NUSConnectionState = .stopped
    @Published public private(set) var bluetoothStateNote: String = "蓝牙状态未知"
    @Published public private(set) var advertisingNote: String = "未广播"
    @Published public private(set) var diagnostics: [String] = []
    /// Latest observed authorization state. Reflects `CBPeripheralManager.authorization`
    /// on init and updates each time `peripheralManagerDidUpdateState` fires.
    @Published public private(set) var authorizationState: CBManagerAuthorization = .notDetermined

    public var onLineReceived: ((String) -> Void)?

    /// Lazily constructed so that creating `BuddyPeripheralService` never triggers
    /// the system BLE permission prompt. The prompt fires only after the caller
    /// invokes `requestAuthorization()` or `start(...)`.
    private var manager: CBPeripheralManager?

    private var txCharacteristic: CBMutableCharacteristic?
    private var rxCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [UUID: CBCentral] = [:]

    private var framer = NDJSONLineFramer()
    private var pendingChunks: [Data] = []
    private var isStarted = false
    private var advertisedName: String = "Claude-iOS"
    // Claude Desktop scans for devices that advertise NUS + name prefix "Claude".
    // Keep this enabled by default for reliable discovery.
    private var includeServiceUUIDInAdvertisement = true

    public override init() {
        super.init()
        authorizationState = CBPeripheralManager.authorization
    }

    /// Snapshot of the current authorization state without forcing manager creation.
    public static var currentAuthorization: CBManagerAuthorization {
        CBPeripheralManager.authorization
    }

    /// Triggers the system Bluetooth permission prompt when the user has not
    /// yet decided. Safe to call repeatedly — subsequent calls just re-use
    /// the existing peripheral manager.
    public func requestAuthorization() {
        _ = ensureManager()
    }

    @discardableResult
    private func ensureManager() -> CBPeripheralManager {
        if let manager { return manager }
        let created = CBPeripheralManager(delegate: self, queue: nil)
        manager = created
        authorizationState = CBPeripheralManager.authorization
        log("MANAGER created state=\(created.state.rawValue) auth=\(authorizationState.rawValue)")
        return created
    }

    public func start(displayName: String) {
        advertisedName = displayName
        isStarted = true
        log("START requested name=\(displayName)")
        let manager = ensureManager()
        guard manager.state == .poweredOn else {
            bluetoothStateNote = stateNote(for: manager.state)
            log("START blocked state=\(manager.state.rawValue) note=\(bluetoothStateNote)")
            return
        }
        setupAndAdvertiseIfNeeded()
    }

    public func setAdvertisementMode(includeServiceUUID: Bool) {
        includeServiceUUIDInAdvertisement = includeServiceUUID
        log("ADV mode includeServiceUUID=\(includeServiceUUID)")
    }

    public func stop() {
        log("STOP requested")
        isStarted = false
        pendingChunks.removeAll(keepingCapacity: false)
        subscribedCentrals.removeAll(keepingCapacity: false)
        if let manager {
            manager.stopAdvertising()
            manager.removeAllServices()
        }
        txCharacteristic = nil
        rxCharacteristic = nil
        connectionState = .stopped
        advertisingNote = "未广播"
        log("STOP completed")
    }

    @discardableResult
    public func sendLine(_ line: String) -> Bool {
        guard !subscribedCentrals.isEmpty else { return false }
        let payload = Data((line.hasSuffix("\n") ? line : line + "\n").utf8)
        enqueueForNotify(payload)
        drainPendingChunks()
        return true
    }

    private func setupAndAdvertiseIfNeeded() {
        guard txCharacteristic == nil, rxCharacteristic == nil else {
            log("SERVICE reused -> startAdvertising")
            startAdvertising()
            return
        }

        let tx = CBMutableCharacteristic(
            type: NUSUUIDs.tx,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )

        let rx = CBMutableCharacteristic(
            type: NUSUUIDs.rx,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(type: NUSUUIDs.service, primary: true)
        service.characteristics = [tx, rx]

        txCharacteristic = tx
        rxCharacteristic = rx
        log("SERVICE add NUS service=\(NUSUUIDs.serviceString)")
        manager?.add(service)
    }

    private func startAdvertising() {
        guard let manager else { return }
        advertisingNote = "请求开始广播"
        if includeServiceUUIDInAdvertisement {
            log("ADV start mode=name+service name=\(advertisedName) service=\(NUSUUIDs.serviceString)")
            manager.startAdvertising([
                CBAdvertisementDataLocalNameKey: advertisedName,
                CBAdvertisementDataServiceUUIDsKey: [NUSUUIDs.service]
            ])
        } else {
            log("ADV start mode=name-only name=\(advertisedName)")
            manager.startAdvertising([
                CBAdvertisementDataLocalNameKey: advertisedName
            ])
        }
    }

    private func enqueueForNotify(_ data: Data) {
        let chunkSize = 180
        var offset = 0
        while offset < data.count {
            let count = min(chunkSize, data.count - offset)
            pendingChunks.append(data.subdata(in: offset..<(offset + count)))
            offset += count
        }
    }

    private func drainPendingChunks() {
        guard let manager, let txCharacteristic else { return }
        while !pendingChunks.isEmpty {
            let chunk = pendingChunks[0]
            let success = manager.updateValue(chunk, for: txCharacteristic, onSubscribedCentrals: nil)
            if success {
                pendingChunks.removeFirst()
            } else {
                return
            }
        }
    }

    private func handleIncomingChunk(_ value: Data) {
        do {
            let lines = try framer.ingest(value)
            for line in lines {
                onLineReceived?(line)
            }
        } catch {
            framer.reset()
        }
    }
}

extension BuddyPeripheralService: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        bluetoothStateNote = stateNote(for: peripheral.state)
        authorizationState = CBPeripheralManager.authorization
        log("STATE changed=\(peripheral.state.rawValue) note=\(bluetoothStateNote) auth=\(authorizationState.rawValue)")
        if peripheral.state == .poweredOn {
            guard isStarted else { return }
            setupAndAdvertiseIfNeeded()
        } else {
            connectionState = .stopped
            advertisingNote = "未广播"
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            connectionState = .stopped
            advertisingNote = "服务注册失败: \(error.localizedDescription)"
            log("SERVICE add failed error=\(error.localizedDescription)")
            return
        }
        log("SERVICE add success uuid=\(service.uuid.uuidString)")
        guard isStarted else { return }
        startAdvertising()
    }

    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            connectionState = .stopped
            advertisingNote = "广播失败: \(error.localizedDescription)"
            log("ADV failed error=\(error.localizedDescription)")
            return
        }

        advertisingNote = "广播中"
        connectionState = subscribedCentrals.isEmpty ? .advertising : .connected(centralCount: subscribedCentrals.count)
        log("ADV started ok")
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        subscribedCentrals[central.identifier] = central
        connectionState = .connected(centralCount: subscribedCentrals.count)
        advertisingNote = "已连接"
        log("SUBSCRIBE central=\(central.identifier.uuidString) count=\(subscribedCentrals.count)")
        drainPendingChunks()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeValue(forKey: central.identifier)
        connectionState = subscribedCentrals.isEmpty ? .advertising : .connected(centralCount: subscribedCentrals.count)
        advertisingNote = subscribedCentrals.isEmpty ? "广播中" : "已连接"
        log("UNSUBSCRIBE central=\(central.identifier.uuidString) count=\(subscribedCentrals.count)")
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        drainPendingChunks()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log("WRITE requests=\(requests.count)")
        for request in requests {
            guard request.characteristic.uuid == NUSUUIDs.rx else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                log("WRITE unsupported characteristic=\(request.characteristic.uuid.uuidString)")
                continue
            }
            if let value = request.value {
                handleIncomingChunk(value)
                log("WRITE rx bytes=\(value.count)")
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    private func log(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        diagnostics.insert("[\(stamp)] \(line)", at: 0)
        if diagnostics.count > 300 {
            diagnostics.removeLast(diagnostics.count - 300)
        }
    }

    private func stateNote(for state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "蓝牙初始化中"
        case .resetting:
            return "蓝牙重置中"
        case .unsupported:
            return "设备不支持 BLE 外设（模拟器不支持）"
        case .unauthorized:
            return "蓝牙权限被拒绝"
        case .poweredOff:
            return "蓝牙已关闭"
        case .poweredOn:
            return "蓝牙已开启"
        @unknown default:
            return "蓝牙状态未知"
        }
    }
}
