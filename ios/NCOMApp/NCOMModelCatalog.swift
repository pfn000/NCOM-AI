import Foundation

struct NCOMModelCatalogEntry: Identifiable, Hashable {
    enum Kind: String, Hashable { case text, vision, projector }
    enum Role: String, CaseIterable, Hashable { case general, coder, reasoner, vision, security, judge }

    let id: String
    let name: String
    let publisher: String
    let repoURL: URL
    let downloadURL: URL
    let sizeLabel: String
    let parameters: String
    let quantization: String
    let role: Role
    let kind: Kind
    let companionModelID: String?
    let license: String
    let notes: String

    static let all: [NCOMModelCatalogEntry] = [
        .init(
            id: "hermes36-genesis-q8",
            name: "Hermes 3.6 35B-A3B Genesis V10",
            publisher: "LuffyTheFox",
            repoURL: URL(string: "https://huggingface.co/LuffyTheFox/Qwen3.6-35B-A3B-Uncensored-Genesis-Hermes-V10-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/LuffyTheFox/Qwen3.6-35B-A3B-Uncensored-Genesis-Hermes-V10-GGUF/resolve/main/Hermes3.6-35B-A3B-Uncensored-Genesis-V10-Q8_K_P.gguf")!,
            sizeLabel: "43.6 GB",
            parameters: "35B-A3B MoE",
            quantization: "Q8_K_P",
            role: .general,
            kind: .text,
            companionModelID: "hermes36-genesis-mmproj",
            license: "Apache-2.0 (repo metadata)",
            notes: "Multimodal/agentic Hermes build. This Q8 file is a heavy desktop-class model, not an iPhone-default download."
        ),
        .init(
            id: "hermes36-genesis-mmproj",
            name: "Hermes 3.6 Genesis Vision Projector",
            publisher: "LuffyTheFox",
            repoURL: URL(string: "https://huggingface.co/LuffyTheFox/Qwen3.6-35B-A3B-Uncensored-Genesis-Hermes-V10-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/LuffyTheFox/Qwen3.6-35B-A3B-Uncensored-Genesis-Hermes-V10-GGUF/resolve/main/mmproj-Hermes3.6-35B-A3B-Uncensored-Genesis-F16.gguf")!,
            sizeLabel: "~899 MB",
            parameters: "Vision projector",
            quantization: "F16",
            role: .vision,
            kind: .projector,
            companionModelID: "hermes36-genesis-q8",
            license: "Apache-2.0 (repo metadata)",
            notes: "Companion projector for the Hermes vision workflow."
        ),
        .init(
            id: "lily-cyber-q2",
            name: "Lily Cybersecurity 7B v0.2",
            publisher: "QuantFactory",
            repoURL: URL(string: "https://huggingface.co/QuantFactory/Lily-Cybersecurity-7B-v0.2-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/QuantFactory/Lily-Cybersecurity-7B-v0.2-GGUF/resolve/main/Lily-Cybersecurity-7B-v0.2.Q2_K.gguf")!,
            sizeLabel: "2.72 GB",
            parameters: "7B",
            quantization: "Q2_K",
            role: .security,
            kind: .text,
            companionModelID: nil,
            license: "Apache-2.0 (repo metadata)",
            notes: "Security-focused specialist. Q2_K is the smaller file from the repository."
        ),
        .init(
            id: "qwen25-coder-q4km",
            name: "Qwen2.5-Coder 7B Instruct",
            publisher: "Qwen",
            repoURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf")!,
            sizeLabel: "4.68 GB",
            parameters: "7B",
            quantization: "Q4_K_M",
            role: .coder,
            kind: .text,
            companionModelID: nil,
            license: "Apache-2.0",
            notes: "Dedicated coding model. The official repository provides multiple GGUF quantizations."
        ),
        .init(
            id: "qwen3vl4-q4km",
            name: "Qwen3-VL 4B Instruct",
            publisher: "Qwen",
            repoURL: URL(string: "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct-GGUF/resolve/main/Qwen3VL-4B-Instruct-Q4_K_M.gguf")!,
            sizeLabel: "2.5 GB",
            parameters: "4B",
            quantization: "Q4_K_M",
            role: .vision,
            kind: .vision,
            companionModelID: "qwen3vl4-mmproj",
            license: "Apache-2.0",
            notes: "Small multimodal model suitable for an iPhone-friendly vision tier, subject to actual device memory."
        ),
        .init(
            id: "qwen3vl4-mmproj",
            name: "Qwen3-VL 4B Vision Projector",
            publisher: "Qwen",
            repoURL: URL(string: "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-VL-4B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-4B-Instruct-F16.gguf")!,
            sizeLabel: "836 MB",
            parameters: "Vision projector",
            quantization: "F16",
            role: .vision,
            kind: .projector,
            companionModelID: "qwen3vl4-q4km",
            license: "Apache-2.0",
            notes: "Companion projector for Qwen3-VL image input."
        ),
        .init(
            id: "devstral2-q4km",
            name: "Devstral Small 2 24B",
            publisher: "Unsloth",
            repoURL: URL(string: "https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/resolve/main/Devstral-Small-2-24B-Instruct-2512-Q4_K_M.gguf")!,
            sizeLabel: "14.3 GB",
            parameters: "24B",
            quantization: "Q4_K_M",
            role: .coder,
            kind: .text,
            companionModelID: "devstral2-mmproj",
            license: "See source repository/model card",
            notes: "Agentic coding specialist. Excellent desktop/remote candidate; generally too large for a small-memory iPhone target."
        ),
        .init(
            id: "devstral2-mmproj",
            name: "Devstral Small 2 Vision Projector",
            publisher: "Unsloth",
            repoURL: URL(string: "https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF")!,
            downloadURL: URL(string: "https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/resolve/main/mmproj-F16.gguf")!,
            sizeLabel: "878 MB",
            parameters: "Vision projector",
            quantization: "F16",
            role: .vision,
            kind: .projector,
            companionModelID: "devstral2-q4km",
            license: "See source repository/model card",
            notes: "Companion projector from the Unsloth GGUF repository."
        )
    ]
}
