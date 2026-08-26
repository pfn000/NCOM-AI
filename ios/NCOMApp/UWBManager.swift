import Foundation
import NearbyInteraction
import CoreBluetooth

@MainActor
final class UWBManager: NSObject, ObservableObject {
    struct Peer: Identifiable, Equatable {
        let id: UUID
        let peripheral: CBPeripheral
        var name: String
        var rssi: Int
    }

    @Published private(set) var distance: Float?
    @Published private(set) var direction: simd_float3?
    @Published private(set) var sessionState = "Idle"
    @Published private(set) var discoveredPeers: [Peer] = []

    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-567812345678")
    private let tokenCharacteristicUUID = CBUUID(string: "87654321-4321-8765-4321-876543210987")

    private var niSession: NISession?
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var discoveredToken: NIDiscoveryToken?
    private var connectedPeripheral: CBPeripheral?
    private var tokenCharacteristic: CBCharacteristic?
    private var localCharacteristic: CBMutableCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)

        guard NISession.isSupported else {
            sessionState = "UWB not supported on this device"
            return
        }

        let session = NISession()
        session.delegate = self
        niSession = session
        sessionState = session.discoveryToken == nil ? "Waiting for discovery token" : "Ready"
    }

    func start() {
        startAdvertising()
        startScanning()
    }

    func stop() {
        centralManager?.stopScan()
        if let connectedPeripheral { centralManager?.cancelPeripheralConnection(connectedPeripheral) }
        connectedPeripheral = nil
        tokenCharacteristic = nil
        discoveredToken = nil
        discoveredPeers.removeAll()
        niSession?.invalidate()
        sessionState = NISession.isSupported ? "Stopped" : "UWB not supported on this device"
    }

    func connect(to peer: Peer) {
        connectedPeripheral = peer.peripheral
        centralManager.connect(peer.peripheral, options: nil)
        sessionState = "Connecting to \(peer.name)"
    }

    private func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        sessionState = "Scanning for UWB peers"
    }

    private func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        if localCharacteristic == nil {
            localCharacteristic = CBMutableCharacteristic(
                type: tokenCharacteristicUUID,
                properties: [.read],
                value: nil,
                permissions: [.readable]
            )
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [localCharacteristic!]
            peripheralManager.add(service)
        }
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
    }

    private func beginInteraction(with token: NIDiscoveryToken) {
        guard let session = niSession else { return }
        discoveredToken = token
        session.run(NINearbyPeerConfiguration(peerToken: token))
        sessionState = "UWB session running"
    }

    private func archiveToken(_ token: NIDiscoveryToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func unarchiveToken(_ data: Data) -> NIDiscoveryToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
    }
}

extension UWBManager: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        Task { @MainActor in
            distance = object.distance
            direction = object.direction
            sessionState = "Connected"
        }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            distance = nil
            direction = nil
            sessionState = "Peer removed"
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in sessionState = "Suspended" }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in sessionState = "Resumed" }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        Task { @MainActor in sessionState = "Invalidated: \(error.localizedDescription)" }
    }
}

extension UWBManager: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            if peripheral.state == .poweredOn { startAdvertising() }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        Task { @MainActor in
            guard request.characteristic.uuid == tokenCharacteristicUUID,
                  let token = niSession?.discoveryToken,
                  let data = archiveToken(token) else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                return
            }
            request.value = data
            peripheral.respond(to: request, withResult: .success)
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            peripheral.respond(to: request, withResult: .writeNotPermitted)
        }
    }
}

extension UWBManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                startScanning()
                startAdvertising()
            } else {
                sessionState = "Bluetooth unavailable"
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "NCOM UWB peer"
            let peer = Peer(id: peripheral.identifier, peripheral: peripheral, name: name, rssi: RSSI.intValue)
            if let existingIndex = discoveredPeers.firstIndex(where: { $0.id == peer.id }) {
                discoveredPeers[existingIndex] = peer
            } else {
                discoveredPeers.append(peer)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            peripheral.delegate = self
            peripheral.discoverServices([serviceUUID])
            sessionState = "Connected over BLE; discovering token"
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in sessionState = "BLE connection failed: \(error?.localizedDescription ?? "unknown error")" }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if connectedPeripheral?.identifier == peripheral.identifier { connectedPeripheral = nil }
            tokenCharacteristic = nil
            sessionState = "BLE disconnected"
        }
    }
}

extension UWBManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard error == nil, let services = peripheral.services else {
                sessionState = "Service discovery failed"
                return
            }
            for service in services where service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([tokenCharacteristicUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            guard error == nil,
                  let characteristic = service.characteristics?.first(where: { $0.uuid == tokenCharacteristicUUID }) else {
                sessionState = "Token characteristic unavailable"
                return
            }
            tokenCharacteristic = characteristic
            peripheral.readValue(for: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            guard characteristic.uuid == tokenCharacteristicUUID,
                  error == nil,
                  let data = characteristic.value,
                  let token = unarchiveToken(data) else {
                sessionState = "Invalid UWB discovery token"
                return
            }
            beginInteraction(with: token)
        }
    }
}
