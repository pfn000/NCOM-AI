import Foundation
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

enum NCOMMetrics {
    static let glassRadius: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
}

struct NCOMLogo: View {
    var size: CGFloat = 30
    var body: some View {
        Text("ᵔ-ᵔ")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .accessibilityLabel("NCOM AI")
    }
}

struct NCOMBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.045, green: 0.05, blue: 0.07), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct NCOMGlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: NCOMMetrics.glassRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay { RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1) }
                }
            }
    }
}

struct NCOMGlassButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(prominent ? .white : .primary)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(prominent ? .regular.tint(.accentColor) : .regular, in: .rect(cornerRadius: NCOMMetrics.glassRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: NCOMMetrics.glassRadius, style: .continuous)
                        .fill(prominent ? Color.accentColor : Color.white.opacity(0.06))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @EnvironmentObject private var engine: NCOMEngine
    @State private var input = ""
    @State private var endpoint = UserDefaults.standard.string(forKey: "ncomEndpoint") ?? "http://127.0.0.1:8765"
    @State private var messages: [Message] = []
    @State private var showAbout = false
    @State private var showActivity = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                NCOMBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: NCOMMetrics.sectionSpacing) {
                        header
                        cognitiveCard
                        conversationCard
                        activityCard
                        quickActions
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showActivity = true } label: { Image(systemName: "waveform.path.ecg") }
                        .accessibilityLabel("NCOM activity")
                    Button { showAbout = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("About NCOM")
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("NCOM settings")
                }
            }
            .sheet(isPresented: $showAbout) { NavigationStack { NCOMAboutView() } }
            .sheet(isPresented: $showActivity) { NavigationStack { NCOMActivityView() }.environmentObject(engine) }
            .sheet(isPresented: $showSettings) { NavigationStack { NCOMSettingsView(endpoint: $endpoint) } }
        }
        .preferredColorScheme(.dark)
        .task { await engine.refreshAvailability() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack { Circle().fill(.white.opacity(0.06)).frame(width: 60, height: 60); NCOMLogo(size: 28) }
            VStack(alignment: .leading, spacing: 3) {
                Text("NCOM AI").font(.system(.title2, design: .rounded).weight(.bold))
                Text("Apple Foundation Models + NCOM Engine").font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Circle().fill(engineColor).frame(width: 9, height: 9)
                Text(engine.state.label).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 4)
    }

    private var cognitiveCard: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("COGNITIVE HEADER")
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile").font(.title2).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Foundation Models").font(.system(.headline, design: .rounded))
                        Text("On-device reasoning and tool calling when available").font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    chip("On device")
                    chip("Private")
                    chip("NCOM tools")
                }
            }
        }
    }

    private var conversationCard: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { sectionTitle("NCOM CONVERSATION"); Spacer(); if engine.state == .thinking { ProgressView().controlSize(.small) } }
                if messages.isEmpty {
                    VStack(spacing: 8) {
                        NCOMLogo(size: 25)
                        Text("Ready when you are").font(.system(.headline, design: .rounded))
                        Text("Talk to NCOM on-device when Apple Foundation Models is available. The engine owns execution and tool boundaries.")
                            .font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(messages) { messageBubble($0) }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message NCOM…", text: $input, axis: .vertical)
                        .font(.system(.body, design: .rounded))
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .lineLimit(1...5)
                        .accessibilityIdentifier("chatInput")
                    Button {
                        let text = input
                        input = ""
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        Task {
                            messages.append(Message(role: .user, content: text))
                            let response = await engine.respond(to: text)
                            messages.append(Message(role: .assistant, content: response))
                        }
                    } label: { Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44) }
                    .buttonStyle(NCOMGlassButtonStyle(prominent: true))
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.state == .thinking)
                    .accessibilityIdentifier("sendButton")
                }
            }
        }
    }

    private var activityCard: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { sectionTitle("DESKTOP / VM ACTIVITY"); Spacer(); Text("OPTIONAL LIVE FEED").font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(.secondary) }
                NCOMDesktopActivityView(endpoint: endpoint)
            }
        }
    }

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { showActivity = true } label: { Label("Activity", systemImage: "waveform.path.ecg") }.buttonStyle(NCOMGlassButtonStyle())
                Button { showAbout = true } label: { Label("About", systemImage: "info.circle") }.buttonStyle(NCOMGlassButtonStyle())
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }.buttonStyle(NCOMGlassButtonStyle())
            }
        }
    }

    private func messageBubble(_ message: Message) -> some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 24) }
            Text(message.content).font(.system(.body, design: .rounded)).padding(12)
                .background(message.role == .user ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if message.role == .user { Spacer(minLength: 24) }
        }
    }

    private func sectionTitle(_ title: String) -> some View { Text(title).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.secondary).tracking(1.0) }
    private func chip(_ title: String) -> some View { Text(title).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(.secondary).padding(.horizontal, 9).padding(.vertical, 6).background(.white.opacity(0.055), in: Capsule()) }
    private var engineColor: Color { switch engine.state { case .ready: return .green; case .thinking: return .orange; case .unavailable: return .gray; case .error: return .red } }
}

struct NCOMActivityView: View {
    @EnvironmentObject private var engine: NCOMEngine
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NCOMGlassCard { VStack(alignment: .leading, spacing: 5) { NCOMLogo(size: 24); Text(engine.state.label).font(.subheadline).foregroundStyle(.secondary) } }
                if engine.events.isEmpty { ContentUnavailableView("No activity yet", systemImage: "waveform.path.ecg", description: Text("NCOM will record model/tool execution here.")) }
                ForEach(engine.events.reversed()) { event in
                    NCOMGlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(event.title).font(.subheadline.bold()); Spacer(); Text(event.timestamp, style: .time).font(.caption).foregroundStyle(.secondary) }
                            Text(event.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }.padding()
        }
        .background(NCOMBackground())
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NCOMSettingsView: View {
    @Binding var endpoint: String
    @State private var showAbout = false
    var body: some View {
        Form {
            Section("Desktop expansion") {
                TextField("NCOM desktop endpoint", text: $endpoint)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .accessibilityIdentifier("endpointField")
                Text("Standalone iOS NCOM does not require this. It is used for optional desktop, VM, and live activity expansion.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Identity") {
                LabeledContent("Bundle ID", value: "com.ncom.ai")
                LabeledContent("Build", value: "0.1.0")
                LabeledContent("Distribution", value: "Private development")
                Button("About NCOM") { showAbout = true }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showAbout) { NavigationStack { NCOMAboutView() } }
    }
}
