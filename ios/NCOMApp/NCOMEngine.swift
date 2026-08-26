import Foundation
import Combine

/// NCOM Engine is the execution/guts layer beneath Apple Foundation Models.
/// NCOM Desktop means the internal VM/workspace by default. A physical PC host
/// is an optional expansion source and is never assumed to be the primary feed.
@MainActor
final class NCOMEngine: ObservableObject {
    @Published private(set) var state: State
    @Published private(set) var events: [Event] = []

    enum State: Equatable {
        case ready
        case thinking
        case unavailable(String)
        case error(String)

        var label: String {
            switch self {
            case .ready: return "Ready"
            case .thinking: return "Thinking"
            case .unavailable(let message): return message
            case .error(let message): return message
            }
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

    init(router: NCOMToolRouter = NCOMToolRouter()) {
        self.router = router
        provider = FoundationModelsBridgeFactory.make(router: router)
        state = provider == nil ? .unavailable("Apple Foundation Models unavailable") : .ready
    }

    func respond(to prompt: String) async -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let provider else {
            let message = "Apple Foundation Models is unavailable on this device/configuration. NCOM Engine is installed, but the on-device Apple model is not currently available."
            state = .unavailable(message)
            events.append(Event(timestamp: .now, title: "Model unavailable", detail: message))
            return message
        }

        state = .thinking
        events.append(Event(timestamp: .now, title: "Foundation Models", detail: "Processing request with NCOM tool router"))

        do {
            let result = try await provider.respond(to: trimmed)
            state = .ready
            events.append(Event(timestamp: .now, title: "Response complete", detail: "Generated on device"))
            return result
        } catch {
            state = .error(error.localizedDescription)
            events.append(Event(timestamp: .now, title: "Generation error", detail: error.localizedDescription))
            return "NCOM generation failed: \(error.localizedDescription)"
        }
    }

    func toolSnapshotText() -> String {
        let snapshot = router.snapshot()
        return "\(snapshot.runtime) • \(snapshot.primaryWorkspace) • version \(snapshot.appVersion) • capabilities: \(snapshot.capabilities.joined(separator: ", "))"
    }
}
