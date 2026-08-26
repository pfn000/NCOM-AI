import Foundation

/// Central in-app tool boundary. The NCOM Desktop surface is the primary internal VM/workspace.
/// The physical PC host is an optional secondary expansion source.
struct NCOMToolRouter: Sendable {
    struct Snapshot: Sendable {
        let runtime: String
        let appVersion: String
        let primaryWorkspace: String
        let capabilities: [String]
    }

    func snapshot() -> Snapshot {
        Snapshot(
            runtime: "NCOM Engine / iOS",
            appVersion: "0.1.0",
            primaryWorkspace: "NCOM Desktop VM",
            capabilities: [
                "local memory",
                "project files",
                "MCP tool routing",
                "Skills",
                "Desktop VM",
                "VM activity display",
                "artifact export"
            ]
        )
    }
}
