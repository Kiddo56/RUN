@preconcurrency import CoreBluetooth
import Foundation
import Observation
import TrackerCore

struct DiscoveredHeartRateSensor: Identifiable, Sendable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
}

enum BLEConnectionState: String, Sendable, Equatable {
    case idle
    case scanning
    case connecting
    case connected
    case bluetoothOff
    case unauthorized
    case unsupported

    var displayLabel: String {
        switch self {
        case .idle: return "Idle"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .bluetoothOff: return "Bluetooth Off"
        case .unauthorized: return "Bluetooth Denied"
        case .unsupported: return "Bluetooth Unavailable"
        }
    }
}

@MainActor
@Observable
final class HeartRateMonitorService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private nonisolated static let heartRateServiceUUID = CBUUID(string: "180D")
    private nonisolated static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    private nonisolated static let heartRateMeasurementUUIDString = "2A37"

    private(set) var connectionState: BLEConnectionState = .idle
    private(set) var currentBPM: Double?
    private(set) var connectedDeviceName: String?
    private(set) var discoveredSensors: [DiscoveredHeartRateSensor] = []
    private(set) var lastUpdateDate: Date?

    private var centralManager: CBCentralManager?
    private var peripheralMap: [UUID: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var wantsScanWhenPoweredOn = false

    func startScanning() {
        if centralManager == nil {
            wantsScanWhenPoweredOn = true
            centralManager = CBCentralManager(delegate: self, queue: .main)
            DiagnosticsLogger.shared.log(.recording, "Initialized CBCentralManager for BLE heart-rate scan")
            return
        }

        guard let centralManager else { return }
        switch centralManager.state {
        case .poweredOn:
            beginScan(on: centralManager)
        case .poweredOff:
            wantsScanWhenPoweredOn = true
            connectionState = .bluetoothOff
        case .unauthorized:
            wantsScanWhenPoweredOn = false
            connectionState = .unauthorized
        case .unsupported:
            wantsScanWhenPoweredOn = false
            connectionState = .unsupported
        default:
            wantsScanWhenPoweredOn = true
        }
    }

    func stopScanning() {
        wantsScanWhenPoweredOn = false
        centralManager?.stopScan()
        if connectionState == .scanning {
            connectionState = (connectedPeripheral != nil) ? .connected : .idle
        }
    }

    func connect(sensorID: UUID) {
        guard let centralManager, let peripheral = peripheralMap[sensorID] else { return }
        stopScanning()
        if let existing = connectedPeripheral, existing.identifier != sensorID {
            centralManager.cancelPeripheralConnection(existing)
        }
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting
        connectedDeviceName = discoveredSensors.first(where: { $0.id == sensorID })?.name ?? peripheral.name ?? "Heart-Rate Sensor"
        centralManager.connect(peripheral, options: nil)
        DiagnosticsLogger.shared.log(.recording, "Connecting BLE heart-rate strap: \(connectedDeviceName ?? sensorID.uuidString)")
    }

    func disconnect() {
        wantsScanWhenPoweredOn = false
        centralManager?.stopScan()
        if let peripheral = connectedPeripheral, let centralManager {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        connectedDeviceName = nil
        currentBPM = nil
        lastUpdateDate = nil
        connectionState = .idle
        DiagnosticsLogger.shared.log(.recording, "Disconnected BLE heart-rate strap")
    }

    func disconnectAndStop() {
        disconnect()
        discoveredSensors = []
        peripheralMap.removeAll()
        centralManager?.delegate = nil
        centralManager = nil
    }

    private func beginScan(on central: CBCentralManager) {
        discoveredSensors = []
        wantsScanWhenPoweredOn = false
        connectionState = .scanning
        central.scanForPeripherals(
            withServices: [Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        DiagnosticsLogger.shared.log(.recording, "Scanning for BLE 0x180D heart-rate peripherals")
    }

    private func handleCentralState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            if wantsScanWhenPoweredOn, let centralManager {
                beginScan(on: centralManager)
            } else if connectedPeripheral != nil {
                connectionState = .connected
            } else {
                connectionState = .idle
            }
        case .poweredOff:
            connectionState = .bluetoothOff
            currentBPM = nil
        case .unauthorized:
            wantsScanWhenPoweredOn = false
            connectionState = .unauthorized
            currentBPM = nil
            DiagnosticsLogger.shared.log(.auth, "Bluetooth permission denied for BLE heart-rate strap")
        case .unsupported:
            wantsScanWhenPoweredOn = false
            connectionState = .unsupported
            currentBPM = nil
        default:
            break
        }
    }

    private func handleDidDiscover(peripheral: CBPeripheral, id: UUID, name: String, rssi: Int) {
        peripheralMap[id] = peripheral
        let entry = DiscoveredHeartRateSensor(id: id, name: name, rssi: rssi)
        if let idx = discoveredSensors.firstIndex(where: { $0.id == id }) {
            discoveredSensors[idx] = entry
        } else {
            discoveredSensors.append(entry)
        }
        discoveredSensors.sort { $0.rssi > $1.rssi }
    }

    private func handleDidConnect(peripheral: CBPeripheral, name: String?) {
        connectedPeripheral = peripheral
        if let name, !name.isEmpty {
            connectedDeviceName = name
        }
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([Self.heartRateServiceUUID])
        DiagnosticsLogger.shared.log(.recording, "Connected BLE heart-rate strap: \(connectedDeviceName ?? peripheral.identifier.uuidString)")
    }

    private func handleDidFailOrDisconnect(errorDescription: String?) {
        connectedPeripheral = nil
        currentBPM = nil
        lastUpdateDate = nil
        connectionState = .idle
        if let errorDescription {
            DiagnosticsLogger.shared.log(.error, "BLE heart-rate strap disconnected: \(errorDescription)")
        } else {
            DiagnosticsLogger.shared.log(.recording, "BLE heart-rate strap disconnected")
        }
    }

    private func handleDidDiscoverServices(peripheral: CBPeripheral, services: [CBService], errorDescription: String?) {
        if let errorDescription {
            DiagnosticsLogger.shared.log(.error, "BLE discoverServices error: \(errorDescription)")
            return
        }
        for service in services where service.uuid == Self.heartRateServiceUUID {
            peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
        }
    }

    private func handleDidDiscoverCharacteristics(
        peripheral: CBPeripheral,
        characteristics: [CBCharacteristic],
        errorDescription: String?
    ) {
        if let errorDescription {
            DiagnosticsLogger.shared.log(.error, "BLE discoverCharacteristics error: \(errorDescription)")
            return
        }
        for characteristic in characteristics where characteristic.uuid == Self.heartRateMeasurementUUID {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    private func handleCharacteristicValue(uuidString: String, value: Data?, errorDescription: String?) {
        if let errorDescription {
            DiagnosticsLogger.shared.log(.error, "BLE characteristic update error: \(errorDescription)")
            return
        }
        guard uuidString.caseInsensitiveCompare(Self.heartRateMeasurementUUIDString) == .orderedSame,
              let value,
              let bpm = BLEHeartRateParser.parseBPM(from: value) else {
            return
        }
        currentBPM = bpm
        lastUpdateDate = Date()
    }

    // MARK: - CBCentralManagerDelegate

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        MainActor.assumeIsolated {
            self.handleCentralState(state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        nonisolated(unsafe) let p = peripheral
        let id = peripheral.identifier
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Heart-Rate Strap"
        let rssiValue = RSSI.intValue
        MainActor.assumeIsolated {
            self.handleDidDiscover(peripheral: p, id: id, name: name, rssi: rssiValue)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        nonisolated(unsafe) let p = peripheral
        let name = peripheral.name
        MainActor.assumeIsolated {
            self.handleDidConnect(peripheral: p, name: name)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let err = error?.localizedDescription
        MainActor.assumeIsolated {
            self.handleDidFailOrDisconnect(errorDescription: err)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let err = error?.localizedDescription
        MainActor.assumeIsolated {
            self.handleDidFailOrDisconnect(errorDescription: err)
        }
    }

    // MARK: - CBPeripheralDelegate

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        nonisolated(unsafe) let p = peripheral
        nonisolated(unsafe) let services = peripheral.services ?? []
        let err = error?.localizedDescription
        MainActor.assumeIsolated {
            self.handleDidDiscoverServices(peripheral: p, services: services, errorDescription: err)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        nonisolated(unsafe) let p = peripheral
        nonisolated(unsafe) let chars = service.characteristics ?? []
        let err = error?.localizedDescription
        MainActor.assumeIsolated {
            self.handleDidDiscoverCharacteristics(peripheral: p, characteristics: chars, errorDescription: err)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        let uuidString = characteristic.uuid.uuidString
        let data = characteristic.value
        let err = error?.localizedDescription
        MainActor.assumeIsolated {
            self.handleCharacteristicValue(uuidString: uuidString, value: data, errorDescription: err)
        }
    }
}
