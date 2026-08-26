import SwiftUI

@main
struct NCOMApp: App {
    @StateObject private var engine = NCOMEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
    }
}

private let ncomGlassRadius: CGFloat = 24

private struct NCOMLogo: View {
    var size: CGFloat = 30
    var body: some View {
        Text("ᵔ-ᵔ")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .accessibilityLabel("NCOM AI")
    }
}

private struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: ncomGlassRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: ncomGlassRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: ncomGlassRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: ncomGlassRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                        }
                }
            }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .foregroundStyle(prominent ? .white : .primary)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: ncomGlassRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(prominent ? .regular.tint(.accentColor) : .regular, in: .rect(cornerRadius: ncomGlassRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: ncomGlassRadius, style: .continuous)
                        .fill(prominent ? Color.accentColor : Color.primary.opacity(0.08))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @EnvironmentObject private var engine: NCOMEngine
    @State private var input = ""
    @State private var messages: [Message] = []

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            header
                            cognitiveHeader
                            conversation
                            enginePanel
                        }
                        .padding(16)
                        .padding(.bottom, 28)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.06)).frame(width: 58, height: 58)
                NCOMLogo(size: 27)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("NCOM AI").font(.system(.title2, design: .rounded).weight(.bold))
                Text("Apple Foundation Models + NCOM Engine")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Circle().fill(engineColor).frame(width: 10, height: 10)
                Text(engine.state.label)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 4)
    }

    private var cognitiveHeader: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("COGNITIVE HEADER")
                HStack(spacing: 12) {
                    Image(systemName: "apple.intelligence")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Foundation Models")
                            .font(.system(.headline, design: .rounded))
                        Text("On-device reasoning and model tool calling")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    chip("On device")
                    chip("Private")
                    chip("Tool calling")
                }
            }
        }
    }

    private var conversation: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionTitle("NCOM CONVERSATION")
                    Spacer()
                    if case .thinking = engine.state { ProgressView().controlSize(.small) }
                }

                if messages.isEmpty {
                    VStack(spacing: 10) {
                        NCOMLogo(size: 25)
                        Text("Ready when you are")
                            .font(.system(.headline, design: .rounded))
                        Text("Ask NCOM something. Apple Foundation Models provides the cognitive layer; NCOM Engine owns the tools and execution boundary.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else {
                    ForEach(messages) { message in
                        messageBubble(message)
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message NCOM…", text: $input, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .lineLimit(1...5)
                        .accessibilityIdentifier("chatInput")

                    Button {
                        let text = input
                        input = ""
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        messages.append(Message(role: .user, content: text))
                        Task {
                            let response = await engine.respond(to: text)
                            messages.append(Message(role: .assistant, content: response))
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.state == .thinking)
                    .accessibilityIdentifier("sendButton")
                }
            }
        }
    }

    private var enginePanel: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("NCOM ENGINE")
                info("Layer", "Tools • MCP • Skills • Memory • VM boundary")
                info("Provider", engine.state == .ready || engine.state == .thinking ? "Apple Foundation Models" : "Unavailable")
                info("Architecture", "Cognitive header → Tool Router → NCOM execution")

                if !engine.events.isEmpty {
                    Divider().opacity(0.45)
                    sectionTitle("ACTIVITY")
                    ForEach(engine.events.suffix(3)) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(.secondary).frame(width: 6, height: 6).padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.system(.footnote, design: .rounded).weight(.semibold))
                                Text(event.detail).font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: Message) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 24) }
            Text(message.content)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(message.role == .user ? Color.accentColor.opacity(0.18) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if message.role == .user { Spacer(minLength: 24) }
        }
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white.opacity(0.055), in: Capsule())
    }

    private func info(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.system(.footnote, design: .rounded))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(1.0)
    }

    private var engineColor: Color {
        switch engine.state {
        case .ready: return .green
        case .thinking: return .orange
        case .unavailable: return .gray
        case .error: return .red
        }
    }
}

private struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    enum Role { case user, assistant }
}
