import SwiftUI
import UniformTypeIdentifiers

struct NCOMModelLabView: View {
    @StateObject private var manager = NCOMLocalModelManager()
    @State private var showImporter = false
    @State private var downloadURL = ""
    @State private var showDownload = false
    @State private var selectedPrompt = "Compare the strengths of the loaded models for coding."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Model Lab").font(.title2.bold()); Spacer(); Text("\(manager.loadedModels.count) loaded").font(.caption).foregroundStyle(.secondary) }
                        Text("Load multiple GGUF models at once. NCOM checks a concurrent-model limit and memory budget before loading.").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button("Import GGUF") { showImporter = true }.buttonStyle(NCOMGlassButtonStyle(prominent: true))
                            Button("Download GGUF") { showDownload = true }.buttonStyle(NCOMGlassButtonStyle())
                        }
                        HStack { Text("Budget"); Spacer(); Text(ByteCountFormatter.string(fromByteCount: manager.loadedBytes, countStyle: .memory) + " loaded") }
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                ForEach(manager.models) { model in
                    NCOMGlassCard {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Image(systemName: "cube.fill").foregroundStyle(.blue)
                                VStack(alignment: .leading) { Text(model.name).font(.headline); Text(ByteCountFormatter.string(fromByteCount: model.bytes, countStyle: .file)).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Text(model.state.rawValue.uppercased()).font(.caption2.bold()).foregroundStyle(stateColor(model.state))
                            }
                            Picker("Role", selection: Binding(get: { model.role }, set: { manager.setRole($0, for: model.id) })) {
                                ForEach(NCOMLocalModelManager.Model.Role.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                            }
                            .pickerStyle(.menu)
                            HStack {
                                if model.state == .loaded || model.state == .generating {
                                    Button("Unload") { manager.unload(model.id) }.buttonStyle(NCOMGlassButtonStyle())
                                } else {
                                    Button("Load") { Task { await manager.load(model.id) } }.buttonStyle(NCOMGlassButtonStyle(prominent: true))
                                }
                                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).lineLimit(2) }
                            }
                        }
                    }
                }

                if !manager.loadedModels.isEmpty {
                    NCOMGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MULTI-MODEL RUN").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("Prompt", text: $selectedPrompt, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...5)
                            Button("Run loaded models concurrently") {
                                Task {
                                    _ = await manager.respond(prompt: selectedPrompt)
                                }
                            }.buttonStyle(NCOMGlassButtonStyle(prominent: true))
                            Text("Each selected model gets its own generation task. Results are returned separately so NCOM can compare or route them.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if !manager.activity.isEmpty {
                    NCOMGlassCard {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("ACTIVITY").font(.caption.bold()).foregroundStyle(.secondary)
                            ForEach(Array(manager.activity.prefix(6).enumerated()), id: \.offset) { _, line in Text(line).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(NCOMBackground())
        .navigationTitle("Model Lab")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { for url in urls { try? manager.importGGUF(from: url) } }
        }
        .sheet(isPresented: $showDownload) {
            NavigationStack {
                Form { Section("GGUF URL") { TextField("https://…/model.gguf", text: $downloadURL).textInputAutocapitalization(.never).autocorrectionDisabled(); Button("Download") { guard let url = URL(string: downloadURL) else { return }; Task { try? await manager.downloadGGUF(from: url); showDownload = false } } } }
                    .navigationTitle("Download Model").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDownload = false } } }
            }
        }
    }

    private func stateColor(_ state: NCOMLocalModelManager.Model.State) -> Color {
        switch state { case .loaded: return .green; case .loading, .generating: return .orange; case .failed: return .red; default: return .secondary }
    }
}
