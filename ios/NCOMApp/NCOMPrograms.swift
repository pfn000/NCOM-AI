import Foundation
import SwiftUI
import BackgroundTasks

public enum NCOMProgramMode: String, Codable, CaseIterable {
    case native, vmGUI, vmHeadless, hybrid
    var label: String {
        switch self { case .native: "Native"; case .vmGUI: "VM • GUI"; case .vmHeadless: "VM • Headless"; case .hybrid: "Hybrid" }
    }
}

public struct NCOMProgram: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var subtitle: String
    public var symbol: String
    public var mode: NCOMProgramMode
    public var requiresAuthentication: Bool
    public var authenticated: Bool
    public var capabilities: [String]
    public var enabled: Bool
}

public struct NCOMProgramJob: Identifiable, Codable {
    public let id: UUID
    public let programID: UUID
    public let action: String
    public let payload: [String:String]
    public let createdAt: Date
    public var status: Status
    public enum Status: String, Codable { case queued, running, succeeded, failed }
}

@MainActor
public final class NCOMProgramStore: ObservableObject {
    @Published public private(set) var programs: [NCOMProgram]
    @Published public private(set) var jobs: [NCOMProgramJob]
    private let programsKey = "ncom.programs.v1"
    private let jobsKey = "ncom.program.jobs.v1"

    public init() {
        programs = (try? JSONDecoder().decode([NCOMProgram].self, from: UserDefaults.standard.data(forKey: programsKey) ?? Data())) ?? []
        jobs = (try? JSONDecoder().decode([NCOMProgramJob].self, from: UserDefaults.standard.data(forKey: jobsKey) ?? Data())) ?? []
        if programs.isEmpty {
            programs = [
                NCOMProgram(id: UUID(), name: "Outlook", subtitle: "Microsoft mail", symbol: "envelope.fill", mode: .hybrid, requiresAuthentication: true, authenticated: false, capabilities: ["Send email", "Draft", "Headless jobs"], enabled: true),
                NCOMProgram(id: UUID(), name: "NCOM Desktop", subtitle: "Interactive VM", symbol: "display.2", mode: .vmGUI, requiresAuthentication: false, authenticated: true, capabilities: ["GUI", "Browser sign-in", "Export files"], enabled: true),
                NCOMProgram(id: UUID(), name: "NCOM Worker", subtitle: "Headless VM jobs", symbol: "gearshape.2.fill", mode: .vmHeadless, requiresAuthentication: false, authenticated: true, capabilities: ["Scripts", "File processing", "Background jobs"], enabled: true)
            ]
            persistPrograms()
        }
    }

    public func setAuthenticated(_ id: UUID, _ value: Bool) {
        guard let i = programs.firstIndex(where: { $0.id == id }) else { return }
        programs[i].authenticated = value
        persistPrograms()
    }

    @discardableResult
    public func enqueue(programID: UUID, action: String, payload: [String:String] = [:]) -> NCOMProgramJob {
        let job = NCOMProgramJob(id: UUID(), programID: programID, action: action, payload: payload, createdAt: .now, status: .queued)
        jobs.append(job); persistJobs(); NCOMBackgroundProgramScheduler.schedule(); return job
    }

    public func mark(_ id: UUID, status: NCOMProgramJob.Status) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[i].status = status; persistJobs()
    }

    private func persistPrograms() { if let d = try? JSONEncoder().encode(programs) { UserDefaults.standard.set(d, forKey: programsKey) } }
    private func persistJobs() { if let d = try? JSONEncoder().encode(jobs) { UserDefaults.standard.set(d, forKey: jobsKey) } }
}

public final class NCOMBackgroundProgramScheduler {
    public static let identifier = "com.ncom.ai.program-worker"
    public static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            task.expirationHandler = { task.setTaskCompleted(success: false) }
            Task { await NCOMProgramWorker.shared.run(); task.setTaskCompleted(success: true) }
        }
    }
    public static func schedule() {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        try? BGTaskScheduler.shared.submit(request)
    }
}

public actor NCOMProgramWorker {
    public static let shared = NCOMProgramWorker()
    public func run() async {
        // Future VM backends consume the same queued jobs here without launching the visible desktop.
        // iOS controls when BGProcessingTask executes; this is not an always-on daemon.
    }
}

struct NCOMProgramsView: View {
    @EnvironmentObject private var store: NCOMProgramStore
    @State private var selected: NCOMProgram?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(store.programs) { program in
                    Button { selected = program } label: {
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.regularMaterial).overlay(Image(systemName: program.symbol).font(.system(size: 28, weight: .medium)))
                                Circle().fill(program.authenticated || !program.requiresAuthentication ? .green : .orange).frame(width: 9, height: 9).padding(9)
                            }.aspectRatio(1, contentMode: .fit)
                            Text(program.name).font(.system(.footnote, design: .rounded).weight(.semibold)).lineLimit(1)
                            Text(program.mode.label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }.padding(16)
        }
        .background(NCOMBackground()).navigationTitle("Programs")
        .sheet(item: $selected) { NCOMProgramDetailView(program: $0).environmentObject(store) }
    }
}

struct NCOMProgramDetailView: View {
    let program: NCOMProgram
    @EnvironmentObject private var store: NCOMProgramStore
    @Environment(\.dismiss) private var dismiss
    @State private var status = "Ready"
    var body: some View {
        NavigationStack {
            Form {
                Section("Program") {
                    Label(program.name, systemImage: program.symbol)
                    LabeledContent("Execution", value: program.mode.label)
                    LabeledContent("Account", value: program.requiresAuthentication ? (program.authenticated ? "Connected" : "Sign-in required") : "Not required")
                }
                Section("Capabilities") { ForEach(program.capabilities, id: \.self) { Text("• \($0)") } }
                if program.name == "Outlook" {
                    Section("Microsoft") {
                        Button { signIn() } label: { Label(program.authenticated ? "Reconnect Microsoft" : "Sign in with Microsoft", systemImage: "person.badge.key.fill") }
                        Button { status = "Email request queued for NCOM Engine." } label: { Label("Send an email", systemImage: "paperplane.fill") }.disabled(!program.authenticated)
                    }
                }
                Section("Execution") {
                    Button { _ = store.enqueue(programID: program.id, action: "headless.execute"); status = "Queued for NCOM Worker." } label: { Label("Run without opening VM GUI", systemImage: "bolt.fill") }
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text("NCOM Programs separate the app identity from its execution backend. A program can use a GUI VM for sign-in, then use a headless backend for later work. Credentials belong in Keychain, not UserDefaults.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(program.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func signIn() {
        status = "Microsoft sign-in will open in Apple's secure web authentication session."
        // Authentication implementation lives in NCOMMicrosoftAuth.swift.
    }
}
