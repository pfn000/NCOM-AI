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

final class NCOMNativeToolRegistry: @unchecked Sendable {
    static let shared = NCOMNativeToolRegistry()

    private let lock = NSLock()
    private var storage: [String: any NCOMNativeTool] = [:]

    private init() {
        storage["osint"] = RealOSINTTool()
    }

    var names: [String] {
        lock.lock(); defer { lock.unlock() }
        return storage.values.map(\.name).sorted()
    }

    func register(_ tool: any NCOMNativeTool) {
        lock.lock(); defer { lock.unlock() }
        storage[tool.id] = tool
    }

    func execute(id: String, input: String) async -> NCOMToolResult {
        let tool: (any NCOMNativeTool)? = {
            lock.lock(); defer { lock.unlock() }
            return storage[id]
        }()
        guard let tool else { return .failure(toolID: id, output: "Tool not found") }
        return await tool.execute(input: input)
    }
}
