import Foundation
@preconcurrency import NearbyInteraction
@preconcurrency import CoreBluetooth

final class UWBManager: NSObject, ObservableObject {
    struct Peer: Identifiable, Equatable {
        let id: UUID
        let peripheral: CBPeripheral
        var name: String
        var rssi: Int

        static func == (lhs: Peer, rhs: Peer) -> Bool {
            lhs.id == rhs.id && lhs.name == rhs.name && lhs.rssi == rhs.rssi
        }
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

        let capabilities = NISession.deviceCapabilities
        guard capabilities.supportsPreciseDistanceMeasurement else {
            sessionState = "Precise UWB ranging unavailable on this device"
            return
        }

        let session = NISession()
        session.delegate = self
        session.delegateQueue = .main
        niSession = session
        sessionState = capabilities.supportsDirectionMeasurement
            ? "Ready • distance + direction"
            : "Ready • distance only"
    }

    func start() {
        guard niSession != nil else {
            sessionState = "UWB unavailable"
            return
        }
        startAdvertising()
        startScanning()
    }

    func stop() {
        centralManager?.stopScan()
        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(connectedPeripheral)
        }
        connectedPeripheral = nil
        tokenCharacteristic = nil
        discoveredPeers.removeAll()
        niSession?.invalidate()
        sessionState = "Stopped"
    }

    func connect(to peer: Peer) {
        connectedPeripheral = peer.peripheral
        centralManager.connect(peer.peripheral, options: nil)
        sessionState = "Connecting to \(peer.name)"
    }

    private func startScanning() {
        guard centralManager.state == .poweredOn else {
            sessionState = "Bluetooth unavailable"
            return
        }
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        sessionState = "Scanning for UWB peers"
    }

    private func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        peripheralManager.removeAllServices()
        let characteristic = CBMutableCharacteristic(
            type: tokenCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        localCharacteristic = characteristic

        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        peripheralManager.add(service)
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
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        distance = object.distance
        direction = object.direction
        sessionState = "Connected"
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        distance = nil
        direction = nil
        sessionState = "Peer removed"
    }

    func sessionWasSuspended(_ session: NISession) {
        sessionState = "Suspended"
    }

    func sessionSuspensionEnded(_ session: NISession) {
        sessionState = "Resumed"
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        sessionState = "Invalidated: \(error.localizedDescription)"
    }
}

extension UWBManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            startAdvertising()
        } else {
            sessionState = "Bluetooth peripheral unavailable"
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == tokenCharacteristicUUID,
              let token = niSession?.discoveryToken,
              let data = archiveToken(token) else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }
        request.value = data
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            peripheral.respond(to: request, withResult: .writeNotPermitted)
        }
    }
}

extension UWBManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            sessionState = "Bluetooth unavailable"
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "NCOM UWB peer"
        let peer = Peer(id: peripheral.identifier, peripheral: peripheral, name: name, rssi: RSSI.intValue)

        if let index = discoveredPeers.firstIndex(where: { $0.id == peer.id }) {
            discoveredPeers[index] = peer
        } else {
            discoveredPeers.append(peer)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
        sessionState = "Connected over BLE; discovering token"
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        sessionState = "BLE connection failed: \(error?.localizedDescription ?? "unknown error")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        tokenCharacteristic = nil
        sessionState = "BLE disconnected"
    }
}

extension UWBManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            sessionState = "Service discovery failed"
            return
        }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([tokenCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == tokenCharacteristicUUID }) else {
            sessionState = "Token characteristic unavailable"
            return
        }
        tokenCharacteristic = characteristic
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
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
