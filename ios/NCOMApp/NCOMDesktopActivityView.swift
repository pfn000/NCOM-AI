import Foundation
import SwiftUI
import UIKit

/// Live NCOM Desktop runtime surface. The runtime may be on this Mac/Linux host
/// or another machine on the local network; iOS must never assume localhost is the PC.
struct NCOMDesktopActivityView: View {
    let initialEndpoint: String
    @State private var endpointText: String
    @State private var phase = "Desktop runtime not connected"
    @State private var detail = "Enter the NCOM runtime address on the same network, then test the connection."
    @State private var screenshot: UIImage?
    @State private var polling = false
    @State private var needsToken = false
    @State private var connectionOK = false
    @AppStorage("ncomFeedToken") private var feedToken = ""

    init(endpoint: String) {
        self.initialEndpoint = endpoint
        _endpointText = State(initialValue: UserDefaults.standard.string(forKey: "ncomEndpoint") ?? endpoint)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle().fill(polling ? .orange : (connectionOK ? .green : .secondary)).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NCOM Desktop Workspace")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                Text(phase)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Refresh") { Task { await refresh() } }
                                .buttonStyle(.bordered)
                        }

                        TextField("http://192.168.1.50:8765", text: $endpointText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("desktopEndpoint")

                        HStack {
                            Button("Save Endpoint") {
                                saveEndpoint()
                                Task { await refresh() }
                            }
                            .buttonStyle(.borderedProminent)

                            if !feedToken.isEmpty {
                                Button("Clear Token") {
                                    feedToken = ""
                                    Task { await refresh() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Text(endpointHint)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                if needsToken {
                    NCOMGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Desktop feed authorization").font(.headline)
                            Text("This runtime requires the NCOM feed token configured on the desktop process.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            HStack {
                                SecureField("X-NCOM-Feed-Token", text: $feedToken)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .accessibilityIdentifier("desktopFeedToken")
                                Button("Retry") { Task { await refresh() } }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if let screenshot {
                    NCOMGlassCard {
                        Image(uiImage: screenshot)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(alignment: .topLeading) {
                                Text("LIVE DESKTOP")
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(10)
                            }
                            .accessibilityLabel("Live NCOM Desktop display")
                    }
                } else {
                    NCOMGlassCard {
                        VStack(spacing: 8) {
                            Image(systemName: connectionOK ? "desktopcomputer" : "wifi.exclamationmark")
                                .font(.system(size: 28))
                                .foregroundStyle(connectionOK ? .green : .secondary)
                            Text("NCOM Desktop Workspace")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(detail)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                    }
                }
            }
            .padding(16)
        }
        .background(NCOMBackground())
        .navigationTitle("Desktop")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
    }

    private var endpointHint: String {
        if endpointText.contains("127.0.0.1") || endpointText.contains("localhost") {
            return "On a physical iPhone, localhost means the iPhone itself. Use the PC's LAN IP, for example http://192.168.1.50:8765."
        }
        return "The desktop runtime must listen on the LAN and the iPhone must be on the same network."
    }

    private func saveEndpoint() {
        let normalized = endpointText.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        endpointText = normalized
        UserDefaults.standard.set(normalized, forKey: "ncomEndpoint")
    }

    private func refresh() async {
        polling = true
        defer { polling = false }
        screenshot = nil
        connectionOK = false
        needsToken = false

        saveEndpoint()
        let base = endpointText.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty, let healthURL = URL(string: base + "/health") else {
            phase = "Invalid runtime endpoint"
            detail = "Enter a complete URL such as http://192.168.1.50:8765."
            return
        }

        do {
            var healthRequest = URLRequest(url: healthURL)
            healthRequest.timeoutInterval = 5
            if !feedToken.isEmpty { healthRequest.setValue(feedToken, forHTTPHeaderField: "X-NCOM-Feed-Token") }
            let (healthData, healthResponse) = try await URLSession.shared.data(for: healthRequest)
            guard let healthHTTP = healthResponse as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(healthHTTP.statusCode) else { throw URLError(.badServerResponse) }
            let health = try JSONDecoder().decode(NCOMHealth.self, from: healthData)
            connectionOK = health.state == "ready"
            phase = connectionOK ? "Connected to NCOM runtime" : "Runtime reported \(health.state)"
            detail = health.modelConfigured ? "Runtime is reachable. Local model backend is configured." : "Runtime is reachable. No GGUF model is configured on the desktop yet."

            let activityURL = URL(string: base + "/v1/activity")!
            var activityRequest = URLRequest(url: activityURL)
            activityRequest.timeoutInterval = 5
            if !feedToken.isEmpty { activityRequest.setValue(feedToken, forHTTPHeaderField: "X-NCOM-Feed-Token") }
            let (data, response) = try await URLSession.shared.data(for: activityRequest)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 {
                needsToken = true
                phase = "Desktop feed requires pairing"
                detail = "Health is reachable, but the workspace feed requires the configured X-NCOM-Feed-Token."
                return
            }
            guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }

            let activity = try JSONDecoder().decode(NCOMDesktopActivity.self, from: data)
            phase = activity.phase
            detail = activity.detail

            if activity.hasScreenshot, let screenshotURL = URL(string: base + "/v1/display/screenshot") {
                var imageRequest = URLRequest(url: screenshotURL)
                imageRequest.timeoutInterval = 10
                if !feedToken.isEmpty { imageRequest.setValue(feedToken, forHTTPHeaderField: "X-NCOM-Feed-Token") }
                let (imageData, imageResponse) = try await URLSession.shared.data(for: imageRequest)
                if let imageHTTP = imageResponse as? HTTPURLResponse, (200...299).contains(imageHTTP.statusCode) {
                    screenshot = UIImage(data: imageData)
                }
            }
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .timedOut || error.code == .cannotFindHost || error.code == .networkConnectionLost {
            phase = "Cannot reach desktop runtime"
            detail = "Verify the PC IP, port 8765, local-network permission, and firewall."
        } catch {
            phase = "Desktop runtime error"
            detail = error.localizedDescription
        }
    }
}

private struct NCOMHealth: Decodable {
    let service: String
    let state: String
    let modelConfigured: Bool

    enum CodingKeys: String, CodingKey {
        case service
        case state
        case modelConfigured = "model_configured"
    }
}

private struct NCOMDesktopActivity: Decodable {
    let phase: String
    let detail: String
    let hasScreenshot: Bool

    enum CodingKeys: String, CodingKey {
        case phase
        case detail
        case hasScreenshot
    }
}
