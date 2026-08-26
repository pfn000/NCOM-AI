import Foundation

protocol NCOMNativeTool: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    func execute(input: String) async -> NCOMToolResult
}

struct NCOMToolResult: Sendable, Codable {
    let toolID: String
    let success: Bool
    let output: String
    let metadata: [String: String]

    static func success(toolID: String, output: String, metadata: [String: String] = [:]) -> NCOMToolResult {
        NCOMToolResult(toolID: toolID, success: true, output: output, metadata: metadata)
    }

    static func failure(toolID: String, output: String, metadata: [String: String] = [:]) -> NCOMToolResult {
        NCOMToolResult(toolID: toolID, success: false, output: output, metadata: metadata)
    }
}

@MainActor
final class NCOMNativeToolRegistry: ObservableObject {
    static let shared = NCOMNativeToolRegistry()
    @Published private(set) var tools: [any NCOMNativeTool] = []

    private init() {
        register(RealOSINTTool())
    }

    var names: [String] { tools.map(\.name).sorted() }

    func register(_ tool: any NCOMNativeTool) {
        tools.removeAll { $0.id == tool.id }
        tools.append(tool)
    }

    func execute(id: String, input: String) async -> NCOMToolResult {
        guard let tool = tools.first(where: { $0.id == id }) else {
            return .failure(toolID: id, output: "Tool not found")
        }
        return await tool.execute(input: input)
    }
}
