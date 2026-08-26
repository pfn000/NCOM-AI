import SwiftUI
import Network
import CoreBluetooth
import CoreNFC

@MainActor
final class NCOMDeviceScanner: NSObject, ObservableObject {
    struct FoundDevice: Identifiable, Equatable {
        let id: UUID
        var name: String
        var transport: String
        var detail: String
        var signal: Int?
    }

    @Published private(set) var devices: [FoundDevice] = []
    @Published private(set) var scanning = false
    @Published private(set) var status = "Idle"

    private var browser: NWBrowser?
    private var bluetooth: CBCentralManager!

    override init() {
        super.init()
        bluetooth = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func start() {
        scanning = true
        status = "Scanning local discovery + Bluetooth"
        browser?.cancel()
        let browser = NWBrowser(for: .bonjour(type: "_ncom._tcp", domain: nil), using: .tcp)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.status = stateLabel(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                for result in results {
                    let name: String
                    switch result.endpoint {
                    case .service(let serviceName, _, _, _): name = serviceName
                    default: name = "NCOM device"
                    }
                    if !self.devices.contains(where: { $0.transport == "Bonjour" && $0.name == name }) {
                        self.devices.append(FoundDevice(id: UUID(), name: name, transport: "Bonjour", detail: "Local NCOM service", signal: nil))
                    }
                }
            }
        }
        browser.start(queue: .main)
        if bluetooth.state == .poweredOn { bluetooth.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]) }
    }

    func stop() {
        browser?.cancel(); browser = nil
        if bluetooth.state == .poweredOn { bluetooth.stopScan() }
        scanning = false
        status = "Idle"
    }

    func clear() { devices.removeAll() }
}

extension NCOMDeviceScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn && scanning { central.scanForPeripherals(withServices: nil, options: nil) }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Bluetooth device"
            if !devices.contains(where: { $0.transport == "Bluetooth" && $0.name == name }) {
                devices.append(FoundDevice(id: peripheral.identifier, name: name, transport: "Bluetooth", detail: "BLE advertisement", signal: RSSI.intValue))
            }
        }
    }
}

private func stateLabel(_ state: NWBrowser.State) -> String {
    switch state { case .setup: return "Setting up discovery"; case .ready: return "Discovery ready"; case .failed(let error): return "Discovery failed: \(error.localizedDescription)"; case .cancelled: return "Discovery stopped"; case .waiting(let error): return "Waiting: \(error.localizedDescription)"; @unknown default: return "Discovery state changed" }
}

struct NCOMDevicesView: View {
    @StateObject private var scanner = NCOMDeviceScanner()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Device Hub").font(.title2.bold()); Spacer(); Circle().fill(scanner.scanning ? .orange : .secondary).frame(width: 9, height: 9) }
                        Text("Discover your authorized NCOM hardware and nearby services.").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button(scanner.scanning ? "Stop" : "Scan") { scanner.scanning ? scanner.stop() : scanner.start() }.buttonStyle(NCOMGlassButtonStyle(prominent: !scanner.scanning))
                            Button("Clear") { scanner.clear() }.buttonStyle(NCOMGlassButtonStyle())
                        }
                        Text(scanner.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(scanner.devices) { device in
                    NCOMGlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: device.transport == "Bluetooth" ? "wave.3.right" : "network")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(device.name).font(.headline)
                                Text("\(device.transport) • \(device.detail)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let signal = device.signal { Text("\(signal) dBm").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
                if scanner.devices.isEmpty { ContentUnavailableView("No devices yet", systemImage: "antenna.radiowaves.left.and.right", description: Text("Start Hail Sniff or Scan to look for NCOM services and Bluetooth advertisements.")) }
            }
            .padding(16)
        }
        .background(NCOMBackground())
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { scanner.stop() }
    }
}

struct NCOMHailSniffView: View {
    @StateObject private var scanner = NCOMDeviceScanner()
    @State private var duration = 30.0
    @State private var elapsed = 0.0
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { NCOMLogo(size: 24); Text("Hail Sniff").font(.title2.bold()); Spacer(); Text(scanner.scanning ? "LISTENING" : "IDLE").font(.caption.bold()).foregroundStyle(scanner.scanning ? .orange : .secondary) }
                        Text("Search for authorized/local devices using the transports available to the app: Bonjour/Wi-Fi and Bluetooth. NFC/UWB are explicit accessory interactions, not unrestricted background scanning.")
                            .font(.footnote).foregroundStyle(.secondary)
                        ProgressView(value: elapsed, total: duration)
                        HStack {
                            Button(scanner.scanning ? "Stop Hail" : "Start Hail") { scanner.scanning ? stop() : start() }.buttonStyle(NCOMGlassButtonStyle(prominent: true))
                            Button("Clear") { scanner.clear() }.buttonStyle(NCOMGlassButtonStyle())
                        }
                    }
                }
                ForEach(scanner.devices) { device in
                    NCOMGlassCard {
                        Label { VStack(alignment: .leading) { Text(device.name).font(.headline); Text("\(device.transport) • \(device.detail)").font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: device.transport == "Bluetooth" ? "wave.3.right" : "network") }
                    }
                }
                if scanner.devices.isEmpty { ContentUnavailableView("No signal found", systemImage: "dot.radiowaves.left.and.right", description: Text("Hail Sniff will keep listening until the timer ends or you stop it.")) }
            }
            .padding(16)
        }
        .background(NCOMBackground())
        .navigationTitle("Hail Sniff")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    private func start() {
        elapsed = 0
        scanner.start()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                elapsed = min(duration, elapsed + 0.5)
                if elapsed >= duration { stop() }
            }
        }
    }
    private func stop() { scanner.stop(); timer?.invalidate(); timer = nil }
}

struct NCOMNFCScannerView: View {
    @State private var message = "Tap Scan to read a supported NFC tag."
    @State private var session: NFCTagReaderSession?

    var body: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("NFC", systemImage: "wave.3.right.circle").font(.headline)
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button("Scan NFC") { startScan() }.buttonStyle(NCOMGlassButtonStyle(prominent: true))
            }
        }
    }

    private func startScan() {
        guard NFCTagReaderSession.readingAvailable else { message = "NFC reading is unavailable on this device."; return }
        let delegate = TagSessionDelegate { result in
            Task { @MainActor in message = result }
        }
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: delegate, queue: nil)
        session?.alertMessage = "Hold your iPhone near the NFC tag."
        session?.begin()
    }
}

private final class TagSessionDelegate: NSObject, NFCTagReaderSessionDelegate {
    let report: (String) -> Void
    init(report: @escaping (String) -> Void) { self.report = report }
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { report("NFC reader active") }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) { report("NFC ended: \(error.localizedDescription)") }
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) { report("Detected \(tags.count) NFC tag(s).") ; session.invalidate() }
}
