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

    public var onLineReceived: ((String) -> Void)?

    private let manager: CBPeripheralManager

    private var txCharacteristic: CBMutableCharacteristic?
    private var rxCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [UUID: CBCentral] = [:]

    private var framer = NDJSONLineFramer()
    private var pendingChunks: [Data] = []
    private var isStarted = false
    private var advertisedName: String = "Claude-iOS"

    public override init() {
        self.manager = CBPeripheralManager(delegate: nil, queue: nil)
        super.init()
        self.manager.delegate = self
    }

    public func start(displayName: String) {
        advertisedName = displayName
        isStarted = true
        guard manager.state == .poweredOn else {
            bluetoothStateNote = stateNote(for: manager.state)
            return
        }
        setupAndAdvertiseIfNeeded()
    }

    public func stop() {
        isStarted = false
        pendingChunks.removeAll(keepingCapacity: false)
        subscribedCentrals.removeAll(keepingCapacity: false)
        manager.stopAdvertising()
        manager.removeAllServices()
        txCharacteristic = nil
        rxCharacteristic = nil
        connectionState = .stopped
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
        manager.add(service)
    }

    private func startAdvertising() {
        connectionState = subscribedCentrals.isEmpty ? .advertising : .connected(centralCount: subscribedCentrals.count)
        manager.startAdvertising([
            CBAdvertisementDataLocalNameKey: advertisedName,
            CBAdvertisementDataServiceUUIDsKey: [NUSUUIDs.service]
        ])
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
        guard let txCharacteristic else { return }
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
        if peripheral.state == .poweredOn {
            guard isStarted else { return }
            setupAndAdvertiseIfNeeded()
        } else {
            connectionState = .stopped
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil, isStarted else { return }
        startAdvertising()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        subscribedCentrals[central.identifier] = central
        connectionState = .connected(centralCount: subscribedCentrals.count)
        drainPendingChunks()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeValue(forKey: central.identifier)
        connectionState = subscribedCentrals.isEmpty ? .advertising : .connected(centralCount: subscribedCentrals.count)
    }

    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        drainPendingChunks()
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard request.characteristic.uuid == NUSUUIDs.rx else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }
            if let value = request.value {
                handleIncomingChunk(value)
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    private func stateNote(for state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "蓝牙初始化中"
        case .resetting:
            return "蓝牙重置中"
        case .unsupported:
            return "设备不支持 BLE 外设"
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
