import Foundation

/// Central in-app tool boundary. Tools are owned by NCOM rather than by a remote host.
/// A desktop/remote runtime can later add adapters without changing the UI or AI provider.
struct NCOMToolRouter: Sendable {
    struct Snapshot: Sendable {
        let runtime: String
        let appVersion: String
        let capabilities: [String]
    }

    func snapshot() -> Snapshot {
        Snapshot(
            runtime: "NCOM Engine / iOS",
            appVersion: "0.1.0",
            capabilities: [
                "local memory",
                "project files",
                "MCP tool routing",
                "Skills",
                "VM boundary",
                "artifact export"
            ]
        )
    }
}
