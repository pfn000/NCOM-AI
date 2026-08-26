import SwiftUI

@main
struct NCOMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - NCOM Liquid Glass Design System

extension CGFloat {
    static let ncomGlassRadius: CGFloat = 24
}

struct NCOMLogo: View {
    var compact = false

    var body: some View {
        Text("ᵔ-ᵔ")
            .font(.system(size: compact ? 22 : 30, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .accessibilityLabel("NCOM AI logo")
    }
}

struct NCOMGlass<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: .ncomGlassRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: .ncomGlassRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 7)
            }
    }
}

struct NCOMGlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: .ncomGlassRadius, style: .continuous)
                    .fill(prominent ? Color.accentColor : Color.clear)
                    .background {
                        if !prominent {
                            RoundedRectangle(cornerRadius: .ncomGlassRadius, style: .continuous)
                                .fill(.thinMaterial)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: .ncomGlassRadius, style: .continuous)
                            .strokeBorder(.white.opacity(prominent ? 0.0 : 0.18), lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NCOMGlassButtonStyle {
    static var ncomGlass: NCOMGlassButtonStyle { .init() }
    static var ncomGlassProminent: NCOMGlassButtonStyle { .init(prominent: true) }
}

struct StatusDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
    }
}

struct ContentView: View {
    @State private var endpoint = UserDefaults.standard.string(forKey: "ncomEndpoint") ?? "http://127.0.0.1:8765"
    @State private var message = ""
    @State private var transcript: [ChatMessage] = []
    @State private var status = RuntimeStatus.disconnected
    @State private var isSending = false

    private enum RuntimeStatus {
        case disconnected
        case checking
        case ready
        case error

        var label: String {
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
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header
                    runtimeCard
                    chatCard
                    endpointCard
                }
                .padding()
            }
            .background {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: endpoint) { _, value in
            UserDefaults.standard.set(value, forKey: "ncomEndpoint")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            NCOMLogo()
            VStack(alignment: .leading, spacing: 2) {
                Text("NCOM AI")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Local-first AI runtime")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusDot(color: status.color, label: status.label)
        }
        .padding(.horizontal, 4)
    }

    private var runtimeCard: some View {
        NCOMGlass {
            VStack(alignment: .leading, spacing: 14) {
                Text("RUNTIME")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                HStack {
                    Label("CPU inference", systemImage: "cpu")
                    Spacer()
                    Text("Local")
                        .foregroundStyle(.secondary)
                }
                .font(.system(.body, design: .rounded))

                HStack {
                    Label("Connection", systemImage: "network")
                    Spacer()
                    Text(endpoint)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.system(.footnote, design: .rounded))

                Button {
                    Task { await health() }
                } label: {
                    Label(status == .checking ? "Checking…" : "Check runtime", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.ncomGlass)
                .disabled(status == .checking)
            }
        }
    }

    private var chatCard: some View {
        NCOMGlass {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CHAT")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Spacer()
                    if isSending {
                        ProgressView()
                    }
                }

                if transcript.isEmpty {
                    VStack(spacing: 10) {
                        NCOMLogo(compact: true)
                        Text("Talk to your NCOM runtime")
                            .font(.system(.headline, design: .rounded))
                        Text("Messages are sent to the endpoint configured below.")
                            .font(.system(.subheadline, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
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
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .lineLimit(1...5)
                        .accessibilityIdentifier("chatInput")

                    Button {
                        let outgoing = message
                        message = ""
                        Task { await send(outgoing) }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.ncomGlassProminent)
                    .accessibilityIdentifier("sendButton")
                    .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var endpointCard: some View {
        NCOMGlass {
            VStack(alignment: .leading, spacing: 12) {
                Text("RUNTIME ENDPOINT")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                TextField("http://192.168.x.x:8765", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("endpointField")

                Text("For a physical iPhone, use the Surface's LAN address. 127.0.0.1 refers to the iPhone/simulator itself.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 26) }

            Text(message.content)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.primary)
                .padding(13)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(message.role == .user ? Color.accentColor.opacity(0.16) : .thinMaterial)
                }

            if message.role == .user { Spacer(minLength: 26) }
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

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user
        case assistant
        case system
    }
}

private struct ChatResponse: Decodable {
    let content: String?
    let error: String?
}
