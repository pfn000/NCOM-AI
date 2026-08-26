import Foundation

struct MCPToolCallResult: Sendable, Codable {
    let id: String
    let result: [String: AnyCodable]
}

struct AnyCodable: Codable, Sendable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let value = try? container.decode(String.self) { self.value = value; return }
            if let value = try? container.decode(Bool.self) { self.value = value; return }
            if let value = try? container.decode(Double.self) { self.value = value; return }
            if let value = try? container.decode([AnyCodable].self) { self.value = value.map(\.value); return }
            if let value = try? container.decode([String: AnyCodable].self) { self.value = value.mapValues(\.value); return }
        }
        self.value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as String: try container.encode(value)
        case let value as Bool: try container.encode(value)
        case let value as Int: try container.encode(value)
        case let value as Double: try container.encode(value)
        case let value as [Any]: try container.encode(value.map(AnyCodable.init))
        case let value as [String: Any]: try container.encode(value.mapValues(AnyCodable.init))
        default: try container.encodeNil()
        }
    }
}

@MainActor
final class MCPToolExecutor: ObservableObject {
    static let shared = MCPToolExecutor()
    @Published private(set) var lastError: String?

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func callTool(endpoint: URL, toolName: String, arguments: [String: Any]) async -> NCOMToolResult {
        let requestID = UUID().uuidString
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": "tools/call",
            "params": [
                "name": toolName,
                "arguments": arguments
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "NCOM.MCP", code: 1, userInfo: [NSLocalizedDescriptionKey: "MCP endpoint returned invalid JSON."])
            }
            if let error = json["error"] as? [String: Any] {
                throw NSError(domain: "NCOM.MCP", code: 2, userInfo: [NSLocalizedDescriptionKey: String(describing: error)])
            }
            let result = json["result"] ?? [:]
            let encoded = try JSONSerialization.data(withJSONObject: result)
            let pretty = String(data: encoded, encoding: .utf8) ?? "{}"
            lastError = nil
            return .success(toolID: "mcp.\(toolName)", output: pretty, metadata: ["transport": "HTTP JSON-RPC", "endpoint": endpoint.absoluteString])
        } catch {
            lastError = error.localizedDescription
            return .failure(toolID: "mcp.\(toolName)", output: error.localizedDescription, metadata: ["endpoint": endpoint.absoluteString])
        }
    }
}
