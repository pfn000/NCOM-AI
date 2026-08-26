import Foundation
import SwiftUI
import UIKit

struct NCOMDesktopActivityView: View {
    let endpoint: String
    @State private var phase = "Desktop feed unavailable"
    @State private var detail = "Connect an NCOM desktop runtime to stream coding, build, and VM activity."
    @State private var screenshot: UIImage?
    @State private var polling = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(polling ? .orange : .secondary).frame(width: 8, height: 8)
                Text(phase).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Button("Refresh") { Task { await refresh() } }
                    .buttonStyle(.bordered)
            }

            if let screenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("Live NCOM desktop or virtual machine display")
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.black.opacity(0.32))
                    .frame(height: 160)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "display")
                                .font(.system(size: 27))
                                .foregroundStyle(.secondary)
                            Text("Desktop / VM display")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(detail)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                        }
                    }
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        polling = true
        defer { polling = false }
        let base = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let activityURL = URL(string: base + "/v1/activity") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: activityURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            let activity = try JSONDecoder().decode(NCOMDesktopActivity.self, from: data)
            phase = activity.phase
            detail = activity.detail

            if activity.hasScreenshot, let screenshotURL = URL(string: base + "/v1/display/screenshot") {
                let (imageData, _) = try await URLSession.shared.data(from: screenshotURL)
                screenshot = UIImage(data: imageData)
            }
        } catch {
            phase = "Desktop feed unavailable"
            detail = "No live desktop/VM feed is available at this endpoint. NCOM will not fabricate one."
            screenshot = nil
        }
    }
}

private struct NCOMDesktopActivity: Decodable {
    let phase: String
    let detail: String
    let hasScreenshot: Bool
}
