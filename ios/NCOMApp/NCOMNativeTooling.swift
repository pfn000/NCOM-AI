import Foundation
import Network

/// Native tool contract used by NCOM's iOS Tool Router.
protocol NCOMNativeTool: Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var requiresNetwork: Bool { get }
    func execute(input: String) async throws -> NCOMToolResult
}

struct NCOMToolResult: Sendable, Codable, Equatable {
    let toolID: String
    let summary: String
    let fields: [String: String]
}

/// Real, asynchronous DNS + RDAP + optional IP-geolocation tool.
/// It intentionally uses public services and performs no credentialed collection.
struct NCOMOSINTTool: NCOMNativeTool {
    let id = "osint"
    let name = "NCOM OSINT"
    let description = "DNS resolution, RDAP registration data, and optional public IP metadata."
    let requiresNetwork = true

    func execute(input: String) async throws -> NCOMToolResult {
        let target = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { throw NCOMToolError.invalidInput("Enter a domain name or IP address.") }
        let isIP = isValidIP(target)
        var fields: [String: String] = [:]
        if !isIP {
            let addresses = try await resolveDNS(host: target)
            fields["dns"] = addresses.isEmpty ? "No addresses resolved" : addresses.joined(separator: ", ")
        }
        if let rdap = try await queryRDAP(query: target) { fields["rdap"] = rdap }
        if isIP, let geo = try await geolocateIP(ip: target) { fields["public_ip_metadata"] = geo }
        let summary = fields.isEmpty ? "No public OSINT data was returned for \(target)." : "Completed public OSINT lookup for \(target)."
        return NCOMToolResult(toolID: id, summary: summary, fields: fields)
    }

    private func resolveDNS(host: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let hostRef = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            var resolved = DarwinBoolean(false)
            guard CFHostStartInfoResolution(hostRef, .addresses, nil) else { continuation.resume(returning: []); return }
            guard let raw = CFHostGetAddressing(hostRef, &resolved)?.takeUnretainedValue() as? [Data] else { continuation.resume(returning: []); return }
            let addresses = raw.compactMap { data -> String? in
                var storage = sockaddr_storage()
                let copyCount = min(data.count, MemoryLayout<sockaddr_storage>.size)
                data.copyBytes(to: &storage, count: copyCount)
                return sockaddrToIP(storage)
            }
            continuation.resume(returning: Array(Set(addresses)).sorted())
        }
    }

    private func sockaddrToIP(_ storage: sockaddr_storage) -> String? {
        var storage = storage
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = withUnsafePointer(to: &storage) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in getnameinfo(pointer, socklen_t(storage.ss_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) } }
        return result == 0 ? String(cString: host) : nil
    }

    private func queryRDAP(query: String) async throws -> String? {
        let path = isValidIP(query) ? "ip" : "domain"
        guard let url = URL(string: "https://rdap.org/\(path)/\(query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query)") else { throw NCOMToolError.invalidInput("Invalid RDAP target.") }
        var request = URLRequest(url: url)
        request.setValue("application/rdap+json, application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var parts: [String] = []
        if let handle = json["handle"] as? String { parts.append("Handle: \(handle)") }
        if let name = (json["ldhName"] as? String) ?? (json["name"] as? String) { parts.append("Name: \(name)") }
        if let status = json["status"] as? [String], !status.isEmpty { parts.append("Status: \(status.joined(separator: ", "))") }
        if let events = json["events"] as? [[String: Any]] {
            for event in events {
                guard let action = event["eventAction"] as? String, let date = event["eventDate"] as? String else { continue }
                if action == "registration" || action == "last changed" { parts.append("\(action.capitalized): \(date)") }
            }
        }
        return parts.isEmpty ? "RDAP response received; no summarized fields found." : parts.joined(separator: " • ")
    }

    private func geolocateIP(ip: String) async throws -> String? {
        guard var components = URLComponents(string: "https://ipwho.is/\(ip)") else { return nil }
        components.queryItems = [URLQueryItem(name: "fields", value: "success,message,ip,country,city,connection")]
        guard let url = components.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], (json["success"] as? Bool) != false else { return nil }
        let connection = json["connection"] as? [String: Any]
        let parts = [json["ip"] as? String, json["city"] as? String, json["country"] as? String, connection?["isp"] as? String].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func isValidIP(_ input: String) -> Bool {
        var v4 = in_addr(); var v6 = in6_addr()
        return input.withCString { pointer in inet_pton(AF_INET, pointer, &v4) == 1 || inet_pton(AF_INET6, pointer, &v6) == 1 }
    }
}

enum NCOMToolError: LocalizedError {
    case invalidInput(String)
    var errorDescription: String? { switch self { case .invalidInput(let message): return message } }
}

struct NCOMToolRegistry: Sendable {
    static let shared = NCOMToolRegistry(tools: [NCOMOSINTTool()])
    let tools: [any NCOMNativeTool]
    init(tools: [any NCOMNativeTool]) { self.tools = tools }
    func tool(id: String) -> (any NCOMNativeTool)? { tools.first { $0.id == id } }
}
