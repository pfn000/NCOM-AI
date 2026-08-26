import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct NCOMAppItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var subtitle: String
    var symbol: String
    var category: String
    var iconFile: String?
}

@MainActor
final class NCOMAppLibrary: ObservableObject {
    @Published private(set) var apps: [NCOMAppItem] = []
    private let key = "ncom.app.library"

    init() {
        if let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([NCOMAppItem].self, from: data) {
            apps = decoded
        }
        if apps.isEmpty {
            apps = [
                NCOMAppItem(id: UUID(), name: "AI Chat", subtitle: "Normal conversation", symbol: "bubble.left.and.bubble.right.fill", category: "AI", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Model Lab", subtitle: "Multi-GGUF models", symbol: "square.3.layers.3d.down.left", category: "AI", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Hail Sniff", subtitle: "Authorized device discovery", symbol: "dot.radiowaves.left.and.right", category: "Devices", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Devices", subtitle: "NFC • UWB • BLE • Wi-Fi", symbol: "antenna.radiowaves.left.and.right", category: "Devices", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "NCOM Desktop", subtitle: "Internal VM workspace", symbol: "display.2", category: "Compute", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "MCP", subtitle: "Tools & servers", symbol: "point.3.connected.trianglepath.dotted", category: "Tools", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Skills", subtitle: "Capability packs", symbol: "square.grid.3x3.middle.filled", category: "Tools", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Acoustic Link", subtitle: "AI-to-AI audio modem", symbol: "waveform", category: "Devices", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Artifacts", subtitle: "Exports & evidence", symbol: "archivebox.fill", category: "Workspace", iconFile: nil),
                NCOMAppItem(id: UUID(), name: "Settings", subtitle: "NCOM configuration", symbol: "gearshape.fill", category: "System", iconFile: nil)
            ]
            persist()
        }
    }

    func add(_ app: NCOMAppItem) { apps.append(app); persist() }
    func remove(_ id: UUID) { apps.removeAll { $0.id == id }; persist() }
    private func persist() { if let data = try? JSONEncoder().encode(apps) { UserDefaults.standard.set(data, forKey: key) } }
}

struct NCOMAppsView: View {
    @StateObject private var library = NCOMAppLibrary()
    @State private var showBuilder = false
    @State private var selectedApp: NCOMAppItem?
    @State private var importedIcon: UIImage?

    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(library.apps) { app in
                        Button { selectedApp = app } label: {
                            NCOMAppTile(app: app)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showBuilder = true } label: {
                        VStack(spacing: 9) {
                            Image(systemName: "plus").font(.title2.weight(.bold))
                            Text("Build App").font(.system(.footnote, design: .rounded).weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.92, contentMode: .fit)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                }
                .padding(16)
            }
            .background(NCOMBackground())
            .navigationTitle("NCOM Apps")
            .sheet(item: $selectedApp) { app in NCOMAppDestination(app: app) }
            .sheet(isPresented: $showBuilder) { NCOMAppBuilderView(library: library) }
        }
    }
}

private struct NCOMAppTile: View {
    let app: NCOMAppItem
    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                Image(systemName: app.symbol)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .aspectRatio(1, contentMode: .fit)
            Text(app.name).font(.system(.footnote, design: .rounded).weight(.semibold)).lineLimit(1)
            Text(app.subtitle).font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

private struct NCOMAppDestination: View {
    let app: NCOMAppItem
    var body: some View {
        switch app.name {
        case "Model Lab": NCOMModelLabView()
        case "Hail Sniff": NCOMHailSniffView()
        case "Devices": NCOMDevicesView()
        case "Acoustic Link": NCOMAcousticLinkView()
        case "NCOM Desktop": NCOMDesktopActivityView(endpoint: UserDefaults.standard.string(forKey: "ncomEndpoint") ?? "http://127.0.0.1:8765").padding()
        default: Text(app.name).font(.largeTitle).padding()
        }
    }
}

struct NCOMAppBuilderView: View {
    @ObservedObject var library: NCOMAppLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var symbol = "app.fill"
    @State private var iconItem: PhotosPickerItem?
    @State private var category = "AI"

    var body: some View {
        NavigationStack {
            Form {
                Section("App") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                    TextField("SF Symbol / icon", text: $symbol)
                    Picker("Category", selection: $category) { ForEach(["AI", "Tools", "Devices", "Compute", "Workspace", "System"], id: \.self) { Text($0).tag($0) } }
                }
                Section("Icon") {
                    PhotosPicker(selection: $iconItem, matching: .images) { Label("Import icon from Photos / Files", systemImage: "photo.badge.plus") }
                    Text("The same importer can use an image transferred from your PC through the Files app.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Button("Create NCOM App") {
                        let app = NCOMAppItem(id: UUID(), name: name.isEmpty ? "New NCOM App" : name, subtitle: description.isEmpty ? "Custom NCOM tool" : description, symbol: symbol.isEmpty ? "app.fill" : symbol, category: category, iconFile: nil)
                        library.add(app)
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Build App")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
