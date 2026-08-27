import Foundation
@preconcurrency import NearbyInteraction
@preconcurrency import CoreBluetooth

@MainActor
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
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        let distance = object.distance
        let direction = object.direction
        Task { @MainActor [distance, direction] in
            self.distance = distance
            self.direction = direction
            self.sessionState = "Connected"
        }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            self.distance = nil
            self.direction = nil
            self.sessionState = "Peer removed"
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in self.sessionState = "Suspended" }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in self.sessionState = "Resumed" }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.sessionState = "Invalidated: \(message)" }
    }
}

extension UWBManager: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        Task { @MainActor in
            if state == .poweredOn {
                startAdvertising()
            } else {
                sessionState = "Bluetooth peripheral unavailable"
            }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let characteristicUUID = request.characteristic.uuid
        let tokenData = (try? niSession?.discoveryToken.flatMap(archiveToken)) ?? nil
        guard characteristicUUID == CBUUID(string: "87654321-4321-8765-4321-876543210987"),
              let tokenData else {
            peripheral.respond(to: request, withResult: .requestNotSupported)
            return
        }
        request.value = tokenData
        peripheral.respond(to: request, withResult: .success)
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            peripheral.respond(to: request, withResult: .writeNotPermitted)
        }
    }
}

extension UWBManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            if state == .poweredOn {
                startScanning()
            } else {
                sessionState = "Bluetooth unavailable"
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "NCOM UWB peer"
        let identifier = peripheral.identifier
        let signal = RSSI.intValue
        Task { @MainActor in
            let peer = Peer(id: identifier, peripheral: peripheral, name: name, rssi: signal)
            if let index = discoveredPeers.firstIndex(where: { $0.id == peer.id }) {
                discoveredPeers[index] = peer
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
        let message = error?.localizedDescription ?? "unknown error"
        Task { @MainActor in sessionState = "BLE connection failed: \(message)" }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            if connectedPeripheral?.identifier == peripheral.identifier {
                connectedPeripheral = nil
            }
            tokenCharacteristic = nil
            sessionState = "BLE disconnected"
        }
    }
}

extension UWBManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services = peripheral.services
        let message = error?.localizedDescription
        Task { @MainActor in
            guard message == nil, let services else {
                sessionState = "Service discovery failed"
                return
            }
            for service in services where service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([tokenCharacteristicUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let characteristic = service.characteristics?.first(where: { $0.uuid == tokenCharacteristicUUID })
        let message = error?.localizedDescription
        Task { @MainActor in
            guard message == nil, let characteristic else {
                sessionState = "Token characteristic unavailable"
                return
            }
            tokenCharacteristic = characteristic
            peripheral.readValue(for: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let data = characteristic.value
        let uuid = characteristic.uuid
        let errorMessage = error?.localizedDescription
        Task { @MainActor in
            guard uuid == tokenCharacteristicUUID,
                  errorMessage == nil,
                  let data,
                  let token = unarchiveToken(data) else {
                sessionState = "Invalid UWB discovery token"
                return
            }
            beginInteraction(with: token)
        }
    }
}
