import Foundation
import Network
import Darwin

struct RealOSINTTool: NCOMNativeTool {
    let id = "osint"
    let name = "OSINT"
    let description = "Authorized DNS, RDAP, and public IP metadata lookups using native iOS networking."

    func execute(input: String) async -> NCOMToolResult {
        let target = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return .failure(toolID: id, output: "Provide a domain name or IP address.") }

        do {
            let isIP = Self.isIP(target)
            async let dns = isIP ? [] : Self.resolveDNS(host: target)
            async let rdap = Self.queryRDAP(target: target, isIP: isIP)
            async let geo = isIP ? Self.geolocateIP(target) : nil

            let dnsValues = await dns
            let rdapValue = await rdap
            let geoValue = await geo

            var lines: [String] = ["Target: \(target)"]
            if !dnsValues.isEmpty { lines.append("DNS: \(dnsValues.joined(separator: ", "))") }
            if let rdapValue { lines.append("RDAP: \(rdapValue)") }
            if let geoValue { lines.append("IP metadata: \(geoValue)") }
            if lines.count == 1 { lines.append("No public records were returned by the configured sources.") }

            return .success(toolID: id, output: lines.joined(separator: "\n"), metadata: ["source": "DNS + RDAP + public IP metadata", "target": target])
        }
    }

    private static func resolveDNS(host: String) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo(ai_flags: AI_ADDRCONFIG, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &result)
                guard status == 0, let first = result else {
                    continuation.resume(returning: [])
                    return
                }
                defer { freeaddrinfo(first) }

                var addresses: [String] = []
                var pointer: UnsafeMutablePointer<addrinfo>? = first
                while let current = pointer {
                    guard let addr = current.pointee.ai_addr else {
                        pointer = current.pointee.ai_next
                        continue
                    }
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let converted = getnameinfo(addr, current.pointee.ai_addrlen, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST)
                    if converted == 0 { addresses.append(String(cString: hostBuffer)) }
                    pointer = current.pointee.ai_next
                }
                continuation.resume(returning: Array(Set(addresses)).sorted())
            }
        }
    }

    private static func queryRDAP(target: String, isIP: Bool) async -> String? {
        let path = isIP ? "ip/\(target)" : "domain/\(target)"
        guard let url = URL(string: "https://rdap.org/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/rdap+json, application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            var parts: [String] = []
            if let name = (json["ldhName"] as? String) ?? (json["name"] as? String) { parts.append("Name: \(name)") }
            if let handle = json["handle"] as? String { parts.append("Handle: \(handle)") }
            if let status = json["status"] as? [String], !status.isEmpty { parts.append("Status: \(status.joined(separator: ", "))") }
            if let events = json["events"] as? [[String: Any]], let registration = events.first(where: { $0["eventAction"] as? String == "registration" }), let date = registration["eventDate"] as? String { parts.append("Registered: \(date)") }
            if let entities = json["entities"] as? [[String: Any]], let registrar = entities.first(where: { ($0["roles"] as? [String])?.contains("registrar") == true }) {
                if let vcard = registrar["vcardArray"] as? [Any], vcard.count > 1, let rows = vcard[1] as? [[Any]] {
                    if let fn = rows.first(where: { $0.first as? String == "fn" })?.dropFirst(3).first as? String { parts.append("Registrar: \(fn)") }
                }
            }
            return parts.isEmpty ? "Record returned" : parts.joined(separator: ", ")
        } catch {
            return nil
        }
    }

    private static func geolocateIP(_ ip: String) async -> String? {
        var components = URLComponents(string: "https://ipwho.is/\(ip)")
        components?.queryItems = [URLQueryItem(name: "fields", value: "success,city,country,isp,ip")]
        guard let url = components?.url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let parts = [json["ip"] as? String, json["city"] as? String, json["country"] as? String, json["isp"] as? String].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            return nil
        }
    }

    private static func isIP(_ value: String) -> Bool {
        var address4 = in_addr()
        var address6 = in6_addr()
        return value.withCString { inet_pton(AF_INET, $0, &address4) == 1 || inet_pton(AF_INET6, $0, &address6) == 1 }
    }
}
