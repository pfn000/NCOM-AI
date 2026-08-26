import Foundation

@MainActor
final class NCOMRuntimeBridge {
    static let shared = NCOMRuntimeBridge()
    private init() {}

    var status: String {
        let foundation = UserDefaults.standard.bool(forKey: "ncom.foundationModelsAvailable")
        return foundation ? "ready with Apple Foundation Models" : "ready with local NCOM capabilities"
    }

    var modelSummary: String {
        let count = UserDefaults.standard.integer(forKey: "ncom.loadedModelCount")
        return count > 0 ? "\(count) local GGUF model(s) are loaded." : "No local GGUF models are currently recorded as loaded."
    }
}
