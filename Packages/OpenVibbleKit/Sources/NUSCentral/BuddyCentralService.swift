// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@preconcurrency import CoreBluetooth
import Combine
import BuddyProtocol

public final class BuddyCentralService: NSObject, ObservableObject {
    @Published public private(set) var connectionState: CentralConnectionState = .unknown
    @Published public private(set) var bluetoothStateNote: String = "Bluetooth state unknown"
    @Published public private(set) var bluetoothPowerState: CBManagerState = .unknown
    @Published public private(set) var discovered: [DiscoveredPeripheral] = []
    @Published public private(set) var diagnostics: [String] = []
    @Published public private(set) var connectedPeripheralName: String?
    @Published public private(set) var connectedPeripheralID: UUID?

    /// Multi-line, copy-friendly expansion of the last connect/disconnect
    /// error — includes NSError domain/code, CBError code name (e.g.
    /// `peerRemovedPairingInformation`), localizedFailureReason and
    /// localizedRecoverySuggestion when the system provides them. Cleared
    /// when a new connect starts or succeeds. The compact
    /// `connectionState.error` only carries `localizedDescription`, which is
    /// often too terse to diagnose iOS 18 bonding issues.
    @Published public private(set) var lastErrorDetail: String?

    /// Called on the delegate queue for every decoded inbound line.
    public var onMessage: ((CentralInboundMessage) -> Void)?

    private var manager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var framer = NDJSONLineFramer()

    private var wantsScan = false
    private var nameFilter: String = NUSCentralUUIDs.claudeNamePrefix

    public override init() {
        super.init()
    }

    public func requestAuthorization() {
        _ = ensureManager()
    }

    @discardableResult
    private func ensureManager() -> CBCentralManager {
        if let manager { return manager }
        let created = CBCentralManager(delegate: self, queue: nil)
        manager = created
        log("MANAGER created state=\(created.state.rawValue)")
        return created
    }

    public func startScan(nameFilter: String = NUSCentralUUIDs.claudeNamePrefix) {
        self.nameFilter = nameFilter
        wantsScan = true
        let manager = ensureManager()
        guard manager.state == .poweredOn else {
            bluetoothStateNote = stateNote(for: manager.state)
            log("SCAN blocked state=\(manager.state.rawValue)")
            return
        }
        beginScanning()
    }

    public func stopScan() {
        wantsScan = false
        manager?.stopScan()
        if case .scanning = connectionState {
            connectionState = .idle
        }
        log("SCAN stopped")
    }

    public func connect(id: UUID) {
        guard let manager else {
            log("CONNECT blocked: no manager")
            return
        }
        lastErrorDetail = nil
        let candidate: CBPeripheral?
        if let existing = peripheral, existing.identifier == id {
            candidate = existing
        } else {
            candidate = manager.retrievePeripherals(withIdentifiers: [id]).first
        }
        guard let target = candidate else {
            log("CONNECT failed: unknown peripheral id=\(id)")
            connectionState = .error("Unknown peripheral")
            return
        }
        manager.stopScan()
        peripheral = target
        target.delegate = self
        connectionState = .connecting
        manager.connect(target, options: nil)
        log("CONNECT requested id=\(id)")
    }

    public func clearLastError() {
        lastErrorDetail = nil
    }

    private static func cbErrorName(_ code: CBError.Code) -> String {
        switch code {
        case .unknown: return "unknown"
        case .invalidParameters: return "invalidParameters"
        case .invalidHandle: return "invalidHandle"
        case .notConnected: return "notConnected"
        case .outOfSpace: return "outOfSpace"
        case .operationCancelled: return "operationCancelled"
        case .connectionTimeout: return "connectionTimeout"
        case .peripheralDisconnected: return "peripheralDisconnected"
        case .uuidNotAllowed: return "uuidNotAllowed"
        case .alreadyAdvertising: return "alreadyAdvertising"
        case .connectionFailed: return "connectionFailed"
        case .connectionLimitReached: return "connectionLimitReached"
        case .unkownDevice: return "unknownDevice"
        case .operationNotSupported: return "operationNotSupported"
        case .peerRemovedPairingInformation: return "peerRemovedPairingInformation"
        case .encryptionTimedOut: return "encryptionTimedOut"
        case .tooManyLEPairedDevices: return "tooManyLEPairedDevices"
        @unknown default: return "case#\(code.rawValue)"
        }
    }

    /// Renders an NSError into a human-readable multi-line description,
    /// surfacing details CoreBluetooth hides behind `localizedDescription`.
    private func describeError(_ error: Error) -> String {
        let ns = error as NSError
        var lines: [String] = []
        lines.append("domain=\(ns.domain) code=\(ns.code)")
        if let cb = error as? CBError {
            lines.append("CBError=\(BuddyCentralService.cbErrorName(cb.code)) (raw=\(cb.code.rawValue))")
        } else if let att = error as? CBATTError {
            lines.append("CBATTError=\(att.code.rawValue)")
        }
        lines.append("description=\(ns.localizedDescription)")
        if let reason = ns.localizedFailureReason {
            lines.append("reason=\(reason)")
        }
        if let sug = ns.localizedRecoverySuggestion {
            lines.append("suggestion=\(sug)")
        }
        return lines.joined(separator: "\n")
    }

    public func disconnect() {
        guard let manager, let p = peripheral else { return }
        connectionState = .disconnecting
        manager.cancelPeripheralConnection(p)
        log("DISCONNECT requested")
    }

    @discardableResult
    public func sendEncodable<T: Encodable>(_ value: T) -> Bool {
        do {
            let line = try NDJSONCodec.encodeLine(value)
            return sendLine(line)
        } catch {
            log("ENCODE failed error=\(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func sendLine(_ line: String) -> Bool {
        guard let p = peripheral, let rx = rxCharacteristic else {
            log("WRITE blocked: not connected")
            return false
        }
        let payload = line.hasSuffix("\n") ? line : line + "\n"
        let data = Data(payload.utf8)
        let type: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse
        let mtu = max(20, p.maximumWriteValueLength(for: type))
        var offset = 0
        while offset < data.count {
            let count = min(mtu, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + count))
            p.writeValue(chunk, for: rx, type: type)
            offset += count
        }
        log("WRITE bytes=\(data.count) mtu=\(mtu) type=\(type == .withoutResponse ? "nr" : "rsp")")
        return true
    }

    private func beginScanning() {
        guard let manager else { return }
        discovered.removeAll()
        manager.scanForPeripherals(withServices: [NUSCentralUUIDs.service], options: nil)
        connectionState = .scanning
        log("SCAN started filter=\(nameFilter)")
    }

    private func resetPeripheralState() {
        peripheral?.delegate = nil
        peripheral = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        framer.reset()
        connectedPeripheralName = nil
        connectedPeripheralID = nil
    }

    private func handleIncomingChunk(_ data: Data) {
        do {
            let lines = try framer.ingest(data)
            for raw in lines {
                let message = CentralInboundDecoder.decode(raw)
                onMessage?(message)
            }
        } catch {
            log("FRAMER error \(error.localizedDescription) — resetting")
            framer.reset()
        }
    }

    private func stateNote(for state: CBManagerState) -> String {
        switch state {
        case .unknown: return "Bluetooth initializing"
        case .resetting: return "Bluetooth resetting"
        case .unsupported: return "Bluetooth not supported"
        case .unauthorized: return "Bluetooth permission denied"
        case .poweredOff: return "Bluetooth is off"
        case .poweredOn: return "Bluetooth is on"
        @unknown default: return "Bluetooth state unknown"
        }
    }

    private func log(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        diagnostics.insert("[\(stamp)] \(line)", at: 0)
        if diagnostics.count > 300 {
            diagnostics.removeLast(diagnostics.count - 300)
        }
    }
}

extension BuddyCentralService: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothStateNote = stateNote(for: central.state)
        bluetoothPowerState = central.state
        log("STATE changed=\(central.state.rawValue) note=\(bluetoothStateNote)")
        switch central.state {
        case .poweredOn:
            if case .unknown = connectionState { connectionState = .idle }
            if wantsScan { beginScanning() }
        case .poweredOff:
            connectionState = .poweredOff
            resetPeripheralState()
        case .unauthorized:
            connectionState = .unauthorized
        case .unsupported:
            connectionState = .unsupported
        default:
            connectionState = .unknown
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? ""
        // Case-insensitive prefix match: iOS peripheral advertises
        // "claude.openvibble" (lowercase) while users who fall back on the
        // system bluetooth name usually have it capitalized as "Claude-…".
        // Matching both keeps discovery robust regardless of foreground state.
        guard advertisedName.lowercased().hasPrefix(nameFilter.lowercased()) else { return }
        let entry = DiscoveredPeripheral(
            id: peripheral.identifier,
            name: advertisedName,
            rssi: RSSI.intValue,
            lastSeen: Date()
        )
        if let index = discovered.firstIndex(where: { $0.id == entry.id }) {
            discovered[index] = entry
        } else {
            discovered.append(entry)
            log("DISCOVER \(advertisedName) rssi=\(RSSI.intValue) id=\(peripheral.identifier)")
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("CONNECTED id=\(peripheral.identifier)")
        lastErrorDetail = nil
        connectedPeripheralID = peripheral.identifier
        connectedPeripheralName = peripheral.name
        peripheral.discoverServices([NUSCentralUUIDs.service])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error {
            let detail = describeError(error)
            lastErrorDetail = detail
            log("CONNECT failed \(detail.replacingOccurrences(of: "\n", with: " | "))")
            connectionState = .error(error.localizedDescription)
        } else {
            log("CONNECT failed error=nil")
            connectionState = .error("connect failed")
        }
        resetPeripheralState()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error {
            let detail = describeError(error)
            lastErrorDetail = detail
            log("DISCONNECTED \(detail.replacingOccurrences(of: "\n", with: " | "))")
        } else {
            log("DISCONNECTED error=nil")
        }
        resetPeripheralState()
        connectionState = .idle
    }
}

extension BuddyCentralService: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            log("DISCOVER services failed error=\(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == NUSCentralUUIDs.service }) else {
            log("DISCOVER services: NUS service not found")
            connectionState = .error("NUS service not found")
            return
        }
        peripheral.discoverCharacteristics([NUSCentralUUIDs.tx, NUSCentralUUIDs.rx], for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            log("DISCOVER characteristics failed error=\(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == NUSCentralUUIDs.tx {
                txCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                log("TX subscribe requested")
            } else if characteristic.uuid == NUSCentralUUIDs.rx {
                rxCharacteristic = characteristic
                log("RX located")
            }
        }
        if txCharacteristic != nil, rxCharacteristic != nil {
            connectionState = .connected
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            log("NOTIFY state error=\(error.localizedDescription) uuid=\(characteristic.uuid.uuidString)")
            return
        }
        log("NOTIFY uuid=\(characteristic.uuid.uuidString) enabled=\(characteristic.isNotifying)")
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            log("RX value error=\(error.localizedDescription)")
            return
        }
        guard characteristic.uuid == NUSCentralUUIDs.tx, let value = characteristic.value else { return }
        handleIncomingChunk(value)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            log("WRITE ack error=\(error.localizedDescription)")
        }
    }
}
