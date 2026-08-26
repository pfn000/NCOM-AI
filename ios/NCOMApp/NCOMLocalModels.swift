import Foundation
import Combine
#if canImport(LlamaSwift)
import LlamaSwift
#endif

@MainActor
final class NCOMLocalModelManager: ObservableObject {
    struct Model: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var fileURL: URL
        var bytes: Int64
        var role: Role
        var state: State
        var error: String?
        enum Role: String, Codable, CaseIterable { case coder, reasoner, vision, general, judge, security }
        enum State: String, Codable { case imported, loading, loaded, generating, unloaded, failed }
    }

    @Published private(set) var models: [Model] = []
    @Published private(set) var activity: [String] = []
    @Published var maxLoadedModels = 2
    @Published var memoryBudgetFraction = 0.55
    private var contexts: [UUID: NCOMLlamaContext] = [:]
    private let modelDirectory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelDirectory = base.appendingPathComponent("NCOM/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        #if canImport(LlamaSwift)
        llama_backend_init()
        #endif
        restore()
    }

    var loadedModels: [Model] { models.filter { $0.state == .loaded || $0.state == .generating } }
    var loadedBytes: Int64 { loadedModels.reduce(0) { $0 + $1.bytes } }
    var budgetBytes: Int64 { Int64(Double(ProcessInfo.processInfo.physicalMemory) * memoryBudgetFraction) }

    func importGGUF(from source: URL) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        guard source.pathExtension.lowercased() == "gguf" else { throw ModelError.notGGUF }
        let destination = modelDirectory.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.copyItem(at: source, to: destination)
        let bytes = Int64((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        models.append(Model(id: UUID(), name: destination.deletingPathExtension().lastPathComponent, fileURL: destination, bytes: bytes, role: .general, state: .unloaded, error: nil))
        persist()
        activity.insert("Imported \(destination.lastPathComponent)", at: 0)
    }

    func downloadGGUF(from url: URL) async throws {
        let (temporary, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw ModelError.downloadFailed }
        guard url.pathExtension.lowercased() == "gguf" else { throw ModelError.notGGUF }
        let name = url.lastPathComponent.isEmpty ? "model.gguf" : url.lastPathComponent
        let destination = modelDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.moveItem(at: temporary, to: destination)
        let bytes = Int64((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        models.append(Model(id: UUID(), name: destination.deletingPathExtension().lastPathComponent, fileURL: destination, bytes: bytes, role: .general, state: .unloaded, error: nil))
        persist()
        activity.insert("Downloaded \(destination.lastPathComponent)", at: 0)
    }

    func setRole(_ role: Model.Role, for id: UUID) { mutate(id) { $0.role = role }; persist() }

    func load(_ id: UUID) async {
        guard let index = models.firstIndex(where: { $0.id == id }) else { return }
        guard contexts[id] == nil else { return }
        if loadedModels.count >= maxLoadedModels { models[index].state = .failed; models[index].error = "Concurrent model limit reached."; return }
        if loadedBytes + models[index].bytes > budgetBytes { models[index].state = .failed; models[index].error = "Configured memory budget would be exceeded."; return }
        let model = models[index]
        models[index].state = .loading
        do {
            let context = try await NCOMLlamaContext.load(path: model.fileURL.path)
            contexts[id] = context
            models[index].state = .loaded
            models[index].error = nil
            activity.insert("Loaded \(model.name)", at: 0)
        } catch {
            models[index].state = .failed
            models[index].error = error.localizedDescription
            activity.insert("Load failed: \(model.name)", at: 0)
        }
    }

    func unload(_ id: UUID) {
        contexts.removeValue(forKey: id)
        mutate(id) { $0.state = .unloaded; $0.error = nil }
        persist()
        if let model = models.first(where: { $0.id == id }) { activity.insert("Unloaded \(model.name)", at: 0) }
    }

    func respond(prompt: String, modelIDs: [UUID]? = nil) async -> String? {
        let selected = loadedModels.filter { modelIDs?.contains($0.id) ?? true }.prefix(maxLoadedModels)
        guard !selected.isEmpty else { return nil }
        for model in selected { mutate(model.id) { $0.state = .generating } }
        defer { for model in selected { mutate(model.id) { $0.state = .loaded } } }
        let results = await withTaskGroup(of: (String, String).self, returning: [(String, String)].self) { group in
            for model in selected {
                guard let context = contexts[model.id] else { continue }
                let name = model.name
                group.addTask {
                    do { return (name, try await context.generate(prompt: prompt)) }
                    catch { return (name, "[\(name) failed: \(error.localizedDescription)]") }
                }
            }
            var result: [(String, String)] = []
            for await item in group { result.append(item) }
            return result
        }
        guard !results.isEmpty else { return nil }
        if results.count == 1 { return results[0].1 }
        return results.map { "### \($0.0)\n\($0.1)" }.joined(separator: "\n\n")
    }

    private func mutate(_ id: UUID, _ body: (inout Model) -> Void) {
        guard let index = models.firstIndex(where: { $0.id == id }) else { return }
        body(&models[index])
    }
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: "ncom.model.manifest"), let restored = try? JSONDecoder().decode([Model].self, from: data) else { return }
        models = restored.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }.map { var copy = $0; copy.state = .unloaded; copy.error = nil; return copy }
    }
    private func persist() { if let data = try? JSONEncoder().encode(models) { UserDefaults.standard.set(data, forKey: "ncom.model.manifest") } }
    enum ModelError: LocalizedError { case notGGUF, downloadFailed; var errorDescription: String? { self == .notGGUF ? "NCOM accepts GGUF model files." : "The model download failed." } }
}

#if canImport(LlamaSwift)
actor NCOMLlamaContext {
    private var model: OpaquePointer
    private var context: OpaquePointer
    private var vocab: OpaquePointer
    private var sampler: UnsafeMutablePointer<llama_sampler>
    private var batch: llama_batch
    private var cursor: Int32 = 0

    static func load(path: String) throws -> NCOMLlamaContext {
        var params = llama_model_default_params()
        #if targetEnvironment(simulator)
        params.n_gpu_layers = 0
        #endif
        guard let model = llama_model_load_from_file(path, params) else { throw NCOMLlamaError.modelLoadFailed }
        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 2048
        contextParams.n_batch = 512
        let threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        contextParams.n_threads = Int32(threads)
        contextParams.n_threads_batch = Int32(threads)
        guard let context = llama_init_from_model(model, contextParams) else { llama_model_free(model); throw NCOMLlamaError.contextFailed }
        return NCOMLlamaContext(model: model, context: context)
    }

    private init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        vocab = llama_model_get_vocab(model)
        batch = llama_batch_init(512, 0, 1)
        let samplerParams = llama_sampler_chain_default_params()
        sampler = llama_sampler_chain_init(samplerParams)
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.4))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(1234))
    }

    deinit {
        llama_sampler_free(sampler)
        llama_batch_free(batch)
        llama_model_free(model)
        llama_free(context)
    }

    func generate(prompt: String, maxTokens: Int32 = 256) throws -> String {
        var tokens = [llama_token](repeating: 0, count: max(64, prompt.utf8.count * 2 + 8))
        let tokenCount = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &tokens, Int32(tokens.count), true, true)
        guard tokenCount > 0 else { throw NCOMLlamaError.tokenizationFailed }
        llama_batch_clear(&batch)
        for i in 0..<Int(tokenCount) { batch.token[i] = tokens[i]; batch.pos[i] = Int32(i); batch.n_seq_id[i] = 1; batch.seq_id[i]![0] = 0; batch.logits[i] = 0; batch.n_tokens += 1 }
        batch.logits[Int(batch.n_tokens) - 1] = 1
        guard llama_decode(context, batch) == 0 else { throw NCOMLlamaError.decodeFailed }
        cursor = batch.n_tokens
        var output = ""
        for _ in 0..<maxTokens {
            let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
            if llama_vocab_is_eog(vocab, token) { break }
            var buffer = [CChar](repeating: 0, count: 512)
            let count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, true)
            if count > 0 { output += String(decoding: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }, as: UTF8.self) }
            llama_batch_clear(&batch)
            batch.token[0] = token; batch.pos[0] = cursor; batch.n_seq_id[0] = 1; batch.seq_id[0]![0] = 0; batch.logits[0] = 1; batch.n_tokens = 1
            guard llama_decode(context, batch) == 0 else { throw NCOMLlamaError.decodeFailed }
            cursor += 1
        }
        return output
    }
}
private enum NCOMLlamaError: LocalizedError { case modelLoadFailed, contextFailed, tokenizationFailed, decodeFailed; var errorDescription: String? { switch self { case .modelLoadFailed: return "GGUF model could not be loaded."; case .contextFailed: return "Model context could not be created."; case .tokenizationFailed: return "Tokenizer rejected the prompt."; case .decodeFailed: return "Token generation failed." } } }
#else
actor NCOMLlamaContext {
    static func load(path: String) throws -> NCOMLlamaContext { throw NSError(domain: "NCOM", code: 1, userInfo: [NSLocalizedDescriptionKey: "llama.cpp is not linked in this build."]) }
    func generate(prompt: String, maxTokens: Int32 = 256) throws -> String { throw NSError(domain: "NCOM", code: 2, userInfo: [NSLocalizedDescriptionKey: "llama.cpp is not linked in this build."]) }
}
#endif
