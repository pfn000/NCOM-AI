import Foundation
import Combine

/// NCOM Engine is the execution/guts layer beneath the cognitive model provider.
/// NCOM Desktop means the internal VM/workspace by default; the physical host is optional.
@MainActor
final class NCOMEngine: ObservableObject {
    @Published private(set) var state: State
    @Published private(set) var events: [Event] = []
    let localModels: NCOMLocalModelManager

    enum State: Equatable {
        case ready
        case thinking
        case unavailable(String)
        case error(String)
        var label: String {
            switch self { case .ready: return "Ready"; case .thinking: return "Thinking"; case .unavailable(let message): return message; case .error(let message): return message }
        }
    }

    struct Event: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let title: String
        let detail: String
    }

    private let router: NCOMToolRouter
    private let provider: NCOMAIProvider?

    init(router: NCOMToolRouter = NCOMToolRouter(), localModels: NCOMLocalModelManager = NCOMLocalModelManager()) {
        self.router = router
        self.localModels = localModels
        self.provider = FoundationModelsBridgeFactory.make(router: router)
        self.state = provider == nil && localModels.loadedModels.isEmpty ? .unavailable("Apple Foundation Models unavailable; load a GGUF model in Model Lab") : .ready
    }

    func respond(to prompt: String) async -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        state = .thinking
        events.append(Event(timestamp: .now, title: "NCOM", detail: "Routing request"))

        if let provider {
            do {
                let result = try await provider.respond(to: trimmed)
                state = .ready
                events.append(Event(timestamp: .now, title: "Apple Foundation Models", detail: "Completed on device"))
                return result
            } catch {
                events.append(Event(timestamp: .now, title: "Foundation Models fallback", detail: error.localizedDescription))
            }
        }

        if let localResult = await localModels.respond(prompt: trimmed), !localResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state = .ready
            events.append(Event(timestamp: .now, title: "Local GGUF", detail: "Generated with \(localModels.loadedModels.count) loaded model(s)"))
            return localResult
        }

        let message = provider == nil
            ? "Apple Foundation Models is unavailable and no local GGUF model is loaded. Open Model Lab and import/download at least one GGUF model."
            : "NCOM could not complete the request with Apple Foundation Models and no loaded local GGUF model was available for fallback."
        state = .unavailable(message)
        events.append(Event(timestamp: .now, title: "No inference backend", detail: message))
        return message
    }

    func toolSnapshotText() -> String {
        let snapshot = router.snapshot()
        return "\(snapshot.runtime) • \(snapshot.primaryWorkspace) • version \(snapshot.appVersion) • capabilities: \(snapshot.capabilities.joined(separator: ", "))"
    }
}
