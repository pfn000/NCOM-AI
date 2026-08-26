import SwiftUI
import UniformTypeIdentifiers

struct NCOMModelLabView: View {
    @EnvironmentObject private var manager: NCOMLocalModelManager
    @State private var showImporter = false
    @State private var downloadURL = ""
    @State private var showDownload = false
    @State private var selectedRole: NCOMLocalModelManager.Model.Role?
    @State private var selectedPrompt = "Compare the loaded models for this task and return the strongest answer from each."
    @State private var result: String?
    @State private var errorMessage: String?
    @State private var isRunning = false

    private var catalog: [NCOMModelCatalogEntry] {
        NCOMModelCatalogEntry.all.filter { entry in
            guard entry.kind != .projector else { return false }
            guard let selectedRole else { return true }
            return entry.role == selectedRole
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                overview
                roleFilter
                curated
                localModels
                multiModelRun
                activity
            }
            .padding()
        }
        .background(NCOMBackground())
        .navigationTitle("Model Lab")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data], allowsMultipleSelection: true) { completion in
            switch completion {
            case .success(let urls):
                for url in urls {
                    do { try manager.importGGUF(from: url) }
                    catch { errorMessage = error.localizedDescription }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showDownload) { downloadSheet }
        .alert("NCOM Model Lab", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var overview: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    NCOMLogo(size: 27)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Local Model Lab").font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Apple model first; local GGUF specialists when the task needs more.")
                            .font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack {
                    stat("Loaded", "\(manager.loadedModels.count)")
                    stat("Storage", ByteCountFormatter.string(fromByteCount: manager.models.reduce(Int64(0)) { $0 + $1.bytes }, countStyle: .file))
                    stat("Max active", "\(manager.maxLoadedModels)")
                }
                HStack(spacing: 8) {
                    Button { showImporter = true } label: { Label("Import GGUF", systemImage: "square.and.arrow.down") }
                        .buttonStyle(NCOMGlassButtonStyle(prominent: true))
                    Button { showDownload = true } label: { Label("Download", systemImage: "arrow.down.circle") }
                        .buttonStyle(NCOMGlassButtonStyle())
                }
            }
        }
    }

    private var roleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                roleButton(nil, label: "All")
                ForEach(NCOMLocalModelManager.Model.Role.allCases, id: \.self) { role in
                    roleButton(role, label: role.rawValue.capitalized)
                }
            }
        }
    }

    private func roleButton(_ role: NCOMLocalModelManager.Model.Role?, label: String) -> some View {
        Button(label) { selectedRole = role }
            .buttonStyle(NCOMGlassButtonStyle(prominent: selectedRole == role))
    }

    private var curated: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("CURATED GGUF LIBRARY").font(.caption.bold()).foregroundStyle(.secondary).tracking(1)
            ForEach(catalog) { entry in
                NCOMCatalogModelCard(entry: entry, installed: isInstalled(entry)) {
                    guard !isInstalled(entry) else { return }
                    Task { await download(entry) }
                }
            }
        }
    }

    private var localModels: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("LOCAL MODELS").font(.caption.bold()).foregroundStyle(.secondary).tracking(1)
            if manager.models.isEmpty {
                NCOMGlassCard { Text("No local GGUF models yet. Import one from Files or download one from the curated library.").font(.footnote).foregroundStyle(.secondary) }
            } else {
                ForEach(manager.models) { model in NCOMLocalModelCard(model: model) }
            }
        }
    }

    private var multiModelRun: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("MULTI-GGUF ORCHESTRATION").font(.caption.bold()).foregroundStyle(.secondary).tracking(1)
                    Spacer()
                    Text("\(manager.loadedModels.count) active").font(.caption).foregroundStyle(.secondary)
                }
                Text("NCOM can run multiple loaded models concurrently and return each result for comparison or synthesis. Memory and concurrent-model limits are enforced.")
                    .font(.footnote).foregroundStyle(.secondary)
                TextField("Task for the loaded models", text: $selectedPrompt, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...6)
                Button {
                    isRunning = true
                    Task {
                        result = await manager.respond(prompt: selectedPrompt)
                        isRunning = false
                    }
                } label: {
                    HStack { if isRunning { ProgressView().tint(.white) }; Text(isRunning ? "Running models…" : "Run loaded models concurrently") }
                }
                .buttonStyle(NCOMGlassButtonStyle(prominent: true))
                .disabled(manager.loadedModels.isEmpty || isRunning)
                if let result {
                    Divider().opacity(0.2)
                    Text("RESULTS").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(result).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                }
            }
        }
    }

    private var activity: some View {
        Group {
            if !manager.activity.isEmpty {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("MODEL ACTIVITY").font(.caption.bold()).foregroundStyle(.secondary).tracking(1)
                        ForEach(Array(manager.activity.prefix(8).enumerated()), id: \.offset) { _, line in Text(line).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }

    private var downloadSheet: some View {
        NavigationStack {
            Form {
                Section("Hugging Face / GGUF URL") {
                    TextField("https://…/model.gguf", text: $downloadURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Button("Download model") {
                        guard let url = URL(string: downloadURL), url.pathExtension.lowercased() == "gguf" else { errorMessage = "Enter a direct .gguf download URL."; return }
                        Task {
                            do { try await manager.downloadGGUF(from: url); downloadURL = ""; showDownload = false }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Download GGUF")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDownload = false } } }
        }
    }

    private func isInstalled(_ entry: NCOMModelCatalogEntry) -> Bool { manager.models.contains { $0.name == entry.name } }
    private func download(_ entry: NCOMModelCatalogEntry) async { do { try await manager.downloadGGUF(from: entry.downloadURL) } catch { errorMessage = error.localizedDescription } }
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value).font(.system(.subheadline, design: .rounded).weight(.bold)); Text(label).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NCOMCatalogModelCard: View {
    let entry: NCOMModelCatalogEntry
    let installed: Bool
    let action: () -> Void
    var body: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.name).font(.system(.headline, design: .rounded).weight(.semibold))
                        Text("\(entry.publisher) • \(entry.parameters) • \(entry.quantization)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(); Text(entry.sizeLabel).font(.caption.bold()).foregroundStyle(.secondary)
                }
                Text(entry.notes).font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Source") { UIApplication.shared.open(entry.repoURL) }.buttonStyle(.bordered)
                    Spacer(); Button(installed ? "Downloaded" : "Download") { action() }.buttonStyle(NCOMGlassButtonStyle(prominent: !installed)).disabled(installed)
                }
            }
        }
    }
}

private struct NCOMLocalModelCard: View {
    @EnvironmentObject private var manager: NCOMLocalModelManager
    let model: NCOMLocalModelManager.Model
    var body: some View {
        NCOMGlassCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: iconName).foregroundStyle(stateColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name).font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("\(ByteCountFormatter.string(fromByteCount: model.bytes, countStyle: .file)) • \(model.role.rawValue.capitalized) • \(model.state.rawValue)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Picker("Role", selection: Binding(get: { model.role }, set: { manager.setRole($0, for: model.id) })) {
                    ForEach(NCOMLocalModelManager.Model.Role.allCases, id: \.self) { role in Text(role.rawValue.capitalized).tag(role) }
                }
                .pickerStyle(.menu)
                HStack {
                    if model.state == .loaded || model.state == .generating { Button("Unload") { manager.unload(model.id) }.buttonStyle(.bordered) }
                    else { Button("Load") { Task { await manager.load(model.id) } }.buttonStyle(NCOMGlassButtonStyle(prominent: true)) }
                    Spacer(); if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).lineLimit(2) }
                }
            }
        }
    }
    private var stateColor: Color { switch model.state { case .loaded: return .green; case .loading, .generating: return .orange; case .failed: return .red; default: return .secondary } }
    private var iconName: String { model.state == .loaded || model.state == .generating ? "checkmark.circle.fill" : "shippingbox" }
}
