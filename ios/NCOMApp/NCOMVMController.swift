import Foundation
import Network

@MainActor
final class NCOMVMController: ObservableObject {
    struct VMMachine: Identifiable, Equatable {
        let id: String
        let name: String
        var endpoint: NWEndpoint
        var isRunning: Bool
    }

    @Published private(set) var machines: [VMMachine] = []
    @Published private(set) var status = "Idle"
    @Published private(set) var lastResponse = ""

    private let serviceType = "_ncom-vm._tcp"
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]

    func startDiscovery() {
        stopDiscovery()
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready: self?.status = "NCOM Desktop VM discovery ready"
                case .failed(let error): self?.status = "VM discovery failed: \(error.localizedDescription)"
                case .waiting(let error): self?.status = "VM discovery waiting: \(error.localizedDescription)"
                case .cancelled: self?.status = "VM discovery stopped"
                default: break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                self.machines = results.map {
                    let id = $0.endpoint.debugDescription
                    return VMMachine(id: id, name: id, endpoint: $0.endpoint, isRunning: false)
                }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
        browser.start(queue: .main)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        for connection in connections.values { connection.cancel() }
        connections.removeAll()
        machines.removeAll()
        status = "Idle"
    }

    func send(_ command: String, to machine: VMMachine) {
        let connection: NWConnection
        if let existing = connections[machine.id] {
            connection = existing
        } else {
            let newConnection = NWConnection(to: machine.endpoint, using: .tcp)
            connections[machine.id] = newConnection
            connection = newConnection
            connection.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    if case .failed(let error) = state { self?.status = "VM connection failed: \(error.localizedDescription)" }
                }
            }
            connection.start(queue: .main)
        }

        let payload = Data((command + "\n").utf8)
        connection.send(content: payload, completion: .contentProcessed { [weak self] error in
            Task { @MainActor in
                if let error { self?.status = "VM command failed: \(error.localizedDescription)" }
                else { self?.status = "Command sent to NCOM Desktop VM" }
            }
        })
        receive(from: connection)
    }

    private func receive(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data, !data.isEmpty {
                    self?.lastResponse = String(decoding: data, as: UTF8.self)
                }
                if let error {
                    self?.status = "VM receive failed: \(error.localizedDescription)"
                } else if !isComplete {
                    self?.receive(from: connection)
                }
            }
        }
    }
}
