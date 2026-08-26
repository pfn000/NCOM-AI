import Foundation

protocol NCOMAIProvider: Sendable {
    func respond(to prompt: String) async throws -> String
}

enum FoundationModelsBridgeFactory {
    static func make(router: NCOMToolRouter) -> NCOMAIProvider? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            return AppleFoundationProvider(router: router)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
private struct NCOMRuntimeStatusTool: Tool {
    let snapshot: NCOMToolRouter.Snapshot
    let name = "ncom_runtime_status"
    let description = "Reports the real capabilities of the local NCOM Engine. Use it when the user asks what NCOM can currently do."

    @Generable
    struct Arguments {
        @Guide(description: "The NCOM area to inspect, such as runtime, tools, or capabilities.")
        var scope: String
    }

    func call(arguments: Arguments) async throws -> String {
        if arguments.scope.lowercased().contains("capab") || arguments.scope.lowercased().contains("tool") {
            return "NCOM capabilities: \(snapshot.capabilities.joined(separator: ", "))."
        }
        return "Runtime: \(snapshot.runtime), version \(snapshot.appVersion)."
    }
}

@available(iOS 26.0, *)
private final class AppleFoundationProvider: NCOMAIProvider {
    private let session: LanguageModelSession

    init(router: NCOMToolRouter) {
        let snapshot = router.snapshot()
        session = LanguageModelSession(
            tools: [NCOMRuntimeStatusTool(snapshot: snapshot)],
            instructions: """
            You are NCOM AI. Apple Foundation Models is the cognitive header; NCOM Engine is the execution layer and tool router.
            Use NCOM tools when the request concerns current NCOM capabilities.
            Never invent tool results, files, builds, test results, or system state.
            Never claim an action was executed unless a tool or app subsystem actually returned a result.
            """
        )
    }

    func respond(to prompt: String) async throws -> String {
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif
