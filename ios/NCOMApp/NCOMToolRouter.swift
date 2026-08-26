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

    func snapshot() -> Snapshot {
        let nativeTools = NCOMNativeToolRegistry.shared.names
        return Snapshot(
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
                "native OSINT DNS/RDAP/IP metadata",
                "Nearby Interaction UWB",
                "Bonjour / local discovery",
                "BLE device discovery"
            ],
            nativeTools: nativeTools
        )
    }

    func executeNativeTool(id: String, input: String) async -> NCOMToolResult {
        await NCOMNativeToolRegistry.shared.execute(id: id, input: input)
    }
}
