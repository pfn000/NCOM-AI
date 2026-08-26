import Foundation
import SwiftUI
import UIKit

/// The primary live-work surface in NCOM iOS.
/// "Desktop" means the internal NCOM Desktop VM by default.
/// A physical PC-host feed can be selected later as an optional expansion source.
struct NCOMDesktopActivityView: View {
    let endpoint: String
    @AppStorage("ncomFeedToken") private var feedToken = ""
    @State private var phase = "NCOM Desktop VM unavailable"
    @State private var detail = "The internal NCOM Desktop VM is the default live workspace. Start it to stream coding, build, and VM activity."
    @State private var screenshot: UIImage?
    @State private var polling = false
    @State private var needsToken = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(polling ? .orange : statusColor).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NCOM Desktop VM")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(phase)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { Task { await refresh() } }
                    .buttonStyle(.bordered)
            }

            if let screenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text("DESKTOP VM")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(10)
                    }
                    .accessibilityLabel("Live NCOM Desktop VM display")
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.black.opacity(0.32))
                    .frame(height: 160)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size: 27))
                                .foregroundStyle(.secondary)
                            Text("NCOM Desktop VM")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(detail)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                        }
                    }
            }

            if needsToken {
                HStack(spacing: 8) {
                    SecureField("Desktop feed token", text: $feedToken)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("desktopFeedToken")
                    Button("Save & Retry") { Task { await refresh() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await refresh() }
    }

    private var statusColor: Color { screenshot != nil ? .green : needsToken ? .orange : .secondary }

    private func refresh() async {
        polling = true
        defer { polling = false }
        screenshot = nil
        let base = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let activityURL = URL(string: base + "/v1/activity") else {
            phase = "Invalid NCOM runtime endpoint"
            detail = "NCOM Desktop VM uses the configured NCOM runtime endpoint."
            needsToken = false
            return
        }

        var request = URLRequest(url: activityURL)
        if !feedToken.isEmpty { request.setValue(feedToken, forHTTPHeaderField: "X-NCOM-Feed-Token") }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 401 {
                phase = "Desktop VM feed requires pairing"
                detail = "Authorize the NCOM Desktop VM live feed to view its display."
                needsToken = true
                return
            }
            guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }

            let activity = try JSONDecoder().decode(NCOMDesktopActivity.self, from: data)
            phase = activity.phase
            detail = activity.detail
            needsToken = false

            if activity.hasScreenshot, let screenshotURL = URL(string: base + "/v1/display/screenshot") {
                var imageRequest = URLRequest(url: screenshotURL)
                if !feedToken.isEmpty { imageRequest.setValue(feedToken, forHTTPHeaderField: "X-NCOM-Feed-Token") }
                let (imageData, imageResponse) = try await URLSession.shared.data(for: imageRequest)
                if let imageHTTP = imageResponse as? HTTPURLResponse, (200...299).contains(imageHTTP.statusCode) {
                    screenshot = UIImage(data: imageData)
                }
            }
        } catch {
            phase = "NCOM Desktop VM feed unavailable"
            detail = "The internal Desktop VM is the default source. A physical PC host can be added later as an optional feed."
        }
    }
}

private struct NCOMDesktopActivity: Decodable {
    let phase: String
    let detail: String
    let hasScreenshot: Bool
}
