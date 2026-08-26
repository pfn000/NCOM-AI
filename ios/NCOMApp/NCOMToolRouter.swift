import Foundation

/// Central in-app tool boundary. NCOM Desktop is the primary internal VM/workspace;
/// the physical PC host remains an optional secondary expansion source.
struct NCOMToolRouter: Sendable {
    struct Snapshot: Sendable {
        let runtime: String
        let appVersion: String
        let primaryWorkspace: String
        let capabilities: [String]
        let nativeTools: [String]
    }

    private let registry: NCOMToolRegistry

    init(registry: NCOMToolRegistry = .shared) {
        self.registry = registry
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
                "artifact export",
                "native OSINT DNS/RDAP/IP metadata"
            ],
            nativeTools: registry.tools.map(\.name)
        )
    }

    func executeNativeTool(id: String, input: String) async throws -> NCOMToolResult {
        guard let tool = registry.tool(id: id) else {
            throw NCOMToolError.invalidInput("NCOM native tool '\(id)' is not registered.")
        }
        return try await tool.execute(input: input)
    }
}
