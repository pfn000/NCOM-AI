import Foundation
import SwiftUI

@main
struct NCOMApp: App {
    @StateObject private var engine = NCOMEngine()
    @StateObject private var models = NCOMLocalModelManager()
    @StateObject private var library = NCOMAppLibrary()

    var body: some Scene {
        WindowGroup {
            NCOMRootView()
                .environmentObject(engine)
                .environmentObject(models)
                .environmentObject(library)
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

struct NCOMRootView: View {
    @State private var selection: RootTab = .chat
    @State private var showAbout = false
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selection) {
            ContentView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(RootTab.chat)
            NCOMAppsView()
                .tabItem { Label("Apps", systemImage: "square.grid.3x3.fill") }
                .tag(RootTab.apps)
            NCOMDevicesView()
                .tabItem { Label("Devices", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(RootTab.devices)
            NavigationStack { NCOMDesktopActivityView(endpoint: UserDefaults.standard.string(forKey: "ncomEndpoint") ?? "http://127.0.0.1:8765").padding().background(NCOMBackground()) }
                .tabItem { Label("Desktop", systemImage: "display.2") }
                .tag(RootTab.desktop)
            NavigationStack {
                Form {
                    Section("NCOM") {
                        Button("About NCOM") { showAbout = true }
                        Button("Owner Profile") { showProfile = true }
                    }
                    Section("Model") {
                        Text("Apple Foundation Models acts as the cognitive header when available. Local GGUF models are managed by NCOM Engine.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(RootTab.settings)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAbout) { NavigationStack { NCOMAboutView() } }
        .sheet(isPresented: $showProfile) { NavigationStack { NCOMProfileView() } }
    }

    enum RootTab: Hashable { case chat, apps, devices, desktop, settings }
}

struct ContentView: View {
    @EnvironmentObject private var engine: NCOMEngine
    @EnvironmentObject private var models: NCOMLocalModelManager
    @State private var input = ""
    @State private var messages: [Message] = []
    @State private var showModels = false
    @State private var showActivity = false

    var body: some View {
        NavigationStack {
            ZStack {
                NCOMBackground()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: NCOMMetrics.sectionSpacing) {
                            header
                            cognitiveCard
                            conversationCard(proxy: proxy)
                            modelStrip
                            executionStrip
                        }
                        .padding(16)
                        .safeAreaPadding(.bottom, 14)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showActivity = true } label: { Image(systemName: "waveform.path.ecg") }
                    Button { showModels = true } label: { Image(systemName: "cube") }
                }
            }
            .sheet(isPresented: $showActivity) { NavigationStack { NCOMActivityView() }.environmentObject(engine) }
            .sheet(isPresented: $showModels) { NavigationStack { NCOMModelLabView() }.environmentObject(models) }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack { Circle().fill(.white.opacity(0.06)).frame(width: 60, height: 60); NCOMLogo(size: 28) }
            VStack(alignment: .leading, spacing: 3) {
                Text("NCOM AI").font(.system(.title2, design: .rounded).weight(.bold))
                Text("Apple Foundation Models + NCOM Engine").font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Circle().fill(engineColor).frame(width: 9, height: 9)
                Text(engine.state.label).font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        }
    }

    private var cognitiveCard: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("COGNITIVE HEADER")
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile").font(.title2).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Foundation Models").font(.system(.headline, design: .rounded))
                        Text("Primary on-device reasoning layer; NCOM supplies the tools and execution guts.").font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 8) { chip("On device"); chip("Private"); chip("Tool calling") }
            }
        }
    }

    private func conversationCard(proxy: ScrollViewProxy) -> some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { sectionTitle("CHAT"); Spacer(); if engine.state == .thinking { ProgressView().controlSize(.small) } }
                if messages.isEmpty {
                    VStack(spacing: 9) { NCOMLogo(size: 26); Text("Ready when you are").font(.headline); Text("This is normal AI chat. NCOM can bring tools, models, the Desktop VM, and devices into the conversation when a task needs them.").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                } else {
                    ForEach(messages) { message in messageBubble(message).id(message.id) }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Talk to NCOM…", text: $input, axis: .vertical)
                        .font(.system(.body, design: .rounded)).textFieldStyle(.plain).padding(12)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous)).lineLimit(1...6)
                        .accessibilityIdentifier("chatInput")
                    Button {
                        let text = input; input = ""
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        Task { messages.append(Message(role: .user, content: text)); let response = await engine.respond(to: text); messages.append(Message(role: .assistant, content: response)); if let last = messages.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } } }
                    } label: { Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).frame(width: 44, height: 44) }
                    .buttonStyle(NCOMGlassButtonStyle(prominent: true)).disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.state == .thinking).accessibilityIdentifier("sendButton")
                }
            }
        }
    }

    private var modelStrip: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack { sectionTitle("LOCAL MODELS"); Spacer(); Text("\(models.loadedModels.count) active").font(.caption).foregroundStyle(.secondary) }
                if models.loadedModels.isEmpty { Text("No GGUF model loaded. Import or download models from Model Lab when you want local fallback/parallel inference.").font(.footnote).foregroundStyle(.secondary) }
                else { HStack(spacing: 8) { ForEach(models.loadedModels) { Text($0.name).font(.caption).padding(.horizontal, 9).padding(.vertical, 6).background(.white.opacity(0.055), in: Capsule()) } } }
            }
        }
    }

    private var executionStrip: some View {
        NCOMGlassCard {
            HStack(spacing: 10) { Image(systemName: "bolt.horizontal.circle").foregroundStyle(.orange); VStack(alignment: .leading) { Text("NCOM Engine").font(.headline); Text("Tools • MCP • Skills • Memory • VM • Devices").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("LIVE").font(.caption2.bold()).foregroundStyle(.secondary) }
        }
    }

    private func messageBubble(_ message: Message) -> some View { HStack { if message.role == .assistant { Spacer(minLength: 24) }; Text(message.content).font(.system(.body, design: .rounded)).padding(12).background(message.role == .user ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous)); if message.role == .user { Spacer(minLength: 24) } } }
    private func sectionTitle(_ text: String) -> some View { Text(text).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.secondary).tracking(1.0) }
    private func chip(_ text: String) -> some View { Text(text).font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(.secondary).padding(.horizontal, 9).padding(.vertical, 6).background(.white.opacity(0.055), in: Capsule()) }
    private var engineColor: Color { switch engine.state { case .ready: return .green; case .thinking: return .orange; case .unavailable: return .gray; case .error: return .red } }
}

struct NCOMActivityView: View {
    @EnvironmentObject private var engine: NCOMEngine
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 12) { ForEach(engine.events.reversed()) { event in NCOMGlassCard { HStack(alignment: .top, spacing: 8) { Circle().fill(.secondary).frame(width: 6, height: 6).padding(.top, 6); VStack(alignment: .leading) { Text(event.title).font(.subheadline.bold()); Text(event.detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(event.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary) } } }; if engine.events.isEmpty { ContentUnavailableView("No activity yet", systemImage: "waveform.path.ecg", description: Text("Execution events will appear here.")) } }.padding() }.background(NCOMBackground()).navigationTitle("Activity")
    }
}

private struct Message: Identifiable, Equatable { let id = UUID(); let role: Role; let content: String; enum Role { case user, assistant } }
