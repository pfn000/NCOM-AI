import AppIntents
import Foundation

@MainActor
final class NCOMIntentCoordinator {
    static let shared = NCOMIntentCoordinator()
    private init() {}

    private(set) var lastAction = "Idle"

    func runAgent(name: String, task: String) {
        lastAction = "Agent \(name) requested: \(task)"
        NotificationCenter.default.post(name: .ncomAgentRequested, object: nil, userInfo: [
            "agent": name,
            "task": task
        ])
    }

    func statusSummary() -> String {
        let model = NCOMRuntimeBridge.shared.modelSummary
        return "NCOM is \(NCOMRuntimeBridge.shared.status). \(model). Last action: \(lastAction)."
    }
}

extension Notification.Name {
    static let ncomAgentRequested = Notification.Name("NCOMAgentRequested")
}

struct RunAgentIntent: AppIntent {
    static var title: LocalizedStringResource = "Run NCOM Agent"
    static var description = IntentDescription("Start an NCOM agent task through the local NCOM Engine.")
    static var openAppWhenRun = false

    @Parameter(title: "Agent Name")
    var agentName: String

    @Parameter(title: "Task")
    var task: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await NCOMIntentCoordinator.shared.runAgent(name: agentName, task: task)
        return .result(dialog: "NCOM queued the \(agentName) agent task.")
    }
}

struct CheckNCOMStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check NCOM Status"
    static var description = IntentDescription("Read the current NCOM runtime and model status.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = await NCOMIntentCoordinator.shared.statusSummary()
        return .result(dialog: LocalizedStringResource(stringLiteral: summary))
    }
}

struct ListNCOMToolsIntent: AppIntent {
    static var title: LocalizedStringResource = "List NCOM Tools"
    static var description = IntentDescription("List tools currently registered with NCOM.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tools = NCOMNativeToolRegistry.shared.names.joined(separator: ", ")
        let text = tools.isEmpty ? "No native NCOM tools are currently registered." : "NCOM tools: \(tools)."
        return .result(dialog: LocalizedStringResource(stringLiteral: text))
    }
}

struct OpenNCOMChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Open NCOM Chat"
    static var description = IntentDescription("Open the normal NCOM AI chat interface.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct NCOMAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(intent: RunAgentIntent(), phrases: ["Run \(.applicationName) agent with \(\.$agentName)"], shortTitle: "Run Agent", systemImageName: "cpu"),
            AppShortcut(intent: CheckNCOMStatusIntent(), phrases: ["Check \(.applicationName) status"], shortTitle: "NCOM Status", systemImageName: "gauge.with.dots.needle.67percent"),
            AppShortcut(intent: ListNCOMToolsIntent(), phrases: ["List \(.applicationName) tools"], shortTitle: "NCOM Tools", systemImageName: "wrench.and.screwdriver.fill"),
            AppShortcut(intent: OpenNCOMChatIntent(), phrases: ["Open \(.applicationName) chat"], shortTitle: "Open Chat", systemImageName: "bubble.left.and.bubble.right.fill")
        ]
    }
}
