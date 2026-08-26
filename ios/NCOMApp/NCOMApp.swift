import SwiftUI

@main
struct NCOMApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// MARK: - NCOM Design System

private enum NCOMMetrics {
    static let glassRadius: CGFloat = 24
    static let sectionSpacing: CGFloat = 18
}

private struct NCOMLogo: View {
    var size: CGFloat = 30

    var body: some View {
        Text("ᵔ-ᵔ")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .accessibilityLabel("NCOM AI")
    }
}

private struct NCOMGlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .modifier(NCOMGlassSurface())
    }
}

private struct NCOMGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: NCOMMetrics.glassRadius, style: .continuous))
            } else {
                content
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    }
            }
        }
    }
}

private struct NCOMGlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .modifier(NCOMButtonSurface(prominent: prominent, pressed: configuration.isPressed))
    }
}

private struct NCOMButtonSurface: ViewModifier {
    let prominent: Bool
    let pressed: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content
                    .foregroundStyle(prominent ? .white : .primary)
                    .glassEffect(
                        prominent ? .regular.tint(.accentColor) : .regular,
                        in: .rect(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                    )
            } else {
                content
                    .foregroundStyle(prominent ? .white : .primary)
                    .background(prominent ? Color.accentColor : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                            .strokeBorder(.white.opacity(prominent ? 0 : 0.14), lineWidth: 1)
                    }
            }
        }
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.16), value: pressed)
    }
}

struct ContentView: View {
    @State private var endpoint = UserDefaults.standard.string(forKey: "ncomEndpoint") ?? "http://127.0.0.1:8765"
    @State private var message = ""
    @State private var transcript: [ChatMessage] = []
    @State private var status = RuntimeStatus.disconnected
    @State private var isSending = false

    private enum RuntimeStatus {
        case disconnected, checking, ready, error

        var title: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .checking: return "Checking…"
            case .ready: return "Runtime Ready"
            case .error: return "Runtime Error"
            }
        }

        var color: Color {
            switch self {
            case .disconnected: return .secondary
            case .checking: return .orange
            case .ready: return .green
            case .error: return .red
            }
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.045, green: 0.05, blue: 0.07), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: NCOMMetrics.sectionSpacing) {
                    hero
                    runtimePanel
                    chatPanel
                    endpointPanel
                    quickActions
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: endpoint) { _, value in
            UserDefaults.standard.set(value, forKey: "ncomEndpoint")
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 58, height: 58)
                NCOMLogo(size: 28)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("NCOM AI")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Personal local-first AI runtime")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Circle()
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                Text(status.title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var runtimePanel: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("RUNTIME")

                statusRow(icon: "cpu", title: "Inference", value: "Local")
                statusRow(icon: "network", title: "Endpoint", value: endpoint, truncate: true)

                HStack(spacing: 10) {
                    Button {
                        Task { await health() }
                    } label: {
                        Label(status == .checking ? "Checking…" : "Check runtime", systemImage: "heart.text.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(NCOMGlassButtonStyle(prominent: true))
                    .disabled(status == .checking)
                    .accessibilityIdentifier("healthButton")

                    Button {
                        endpoint = "http://127.0.0.1:8765"
                        status = .disconnected
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 22)
                    }
                    .buttonStyle(NCOMGlassButtonStyle())
                    .accessibilityLabel("Reset endpoint")
                }
            }
        }
    }

    private var chatPanel: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionTitle("CHAT")
                    Spacer()
                    if isSending { ProgressView().controlSize(.small) }
                }

                if transcript.isEmpty {
                    VStack(spacing: 10) {
                        NCOMLogo(size: 25)
                        Text("Ready when you are")
                            .font(.system(.headline, design: .rounded))
                        Text("Your messages go directly to the configured NCOM runtime.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(transcript) { item in
                            messageBubble(item)
                        }
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message NCOM…", text: $message, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .lineLimit(1...5)
                        .accessibilityIdentifier("chatInput")

                    Button {
                        let outgoing = message
                        message = ""
                        Task { await send(outgoing) }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(NCOMGlassButtonStyle(prominent: true))
                    .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("sendButton")
                }
            }
        }
    }

    private var endpointPanel: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("RUNTIME ENDPOINT")
                TextField("http://192.168.x.x:8765", text: $endpoint)
                    .font(.system(.body, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("endpointField")

                Label(
                    "On a physical iPhone, use the Surface's LAN address. 127.0.0.1 refers to the iPhone/simulator itself.",
                    systemImage: "info.circle"
                )
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("QUICK ACCESS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickAction("Projects", systemImage: "folder")
                    quickAction("Agents", systemImage: "cpu")
                    quickAction("MCP", systemImage: "network")
                    quickAction("Artifacts", systemImage: "archivebox")
                    quickAction("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    private func quickAction(_ title: String, systemImage: String) -> some View {
        Button { } label: {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
        }
        .buttonStyle(NCOMGlassButtonStyle())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(1.0)
    }

    private func statusRow(icon: String, title: String, value: String, truncate: Bool = false) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(truncate ? .middle : .tail)
        }
        .font(.system(.subheadline, design: .rounded))
    }

    private func messageBubble(_ item: ChatMessage) -> some View {
        HStack {
            if item.role == .assistant { Spacer(minLength: 24) }

            Text(item.content)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    item.role == .user
                        ? Color.accentColor.opacity(0.18)
                        : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )

            if item.role == .user { Spacer(minLength: 24) }
        }
    }

    private func health() async {
        status = .checking
        guard let url = URL(string: endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health") else {
            status = .error
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                status = .error
                return
            }
            status = http.statusCode == 200 ? .ready : .error
        } catch {
            status = .disconnected
        }
    }

    private func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        transcript.append(ChatMessage(role: .user, content: trimmed))
        isSending = true
        defer { isSending = false }

        guard let url = URL(string: endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat") else {
            transcript.append(ChatMessage(role: .system, content: "Invalid NCOM endpoint."))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "messages": [["role": "user", "content": trimmed]]
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                transcript.append(ChatMessage(role: .system, content: "NCOM returned an HTTP error."))
                status = .error
                return
            }

            let payload = try JSONDecoder().decode(ChatResponse.self, from: data)
            transcript.append(ChatMessage(role: .assistant, content: payload.content ?? payload.error ?? "NCOM returned no content."))
            status = .ready
        } catch {
            transcript.append(ChatMessage(role: .system, content: "Connection error: \(error.localizedDescription)"))
            status = .disconnected
        }
    }
}

private struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role { case user, assistant, system }
}

private struct ChatResponse: Decodable {
    let content: String?
    let error: String?
}
