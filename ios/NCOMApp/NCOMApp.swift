import SwiftUI

@main
struct NCOMApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var endpoint = UserDefaults.standard.string(forKey: "ncomEndpoint") ?? "http://127.0.0.1:8765"
    @State private var message = ""
    @State private var transcript: [String] = []
    @State private var status = "Disconnected"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(transcript.enumerated()), id: \.offset) { _, item in
                            Text(item).frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }.padding()
                }
                HStack {
                    TextField("NCOM endpoint", text: $endpoint).textFieldStyle(.roundedBorder)
                    Button("Health") { Task { await health() } }
                }.padding(.horizontal)
                HStack {
                    TextField("Message", text: $message).textFieldStyle(.roundedBorder)
                    Button("Send") { Task { await send() } }.buttonStyle(.borderedProminent)
                }.padding()
            }
            .navigationTitle("NCOM AI")
            .toolbar { Text(status).font(.caption) }
        }
        .onChange(of: endpoint) { _, value in UserDefaults.standard.set(value, forKey: "ncomEndpoint") }
    }

    func health() async {
        guard let url = URL(string: endpoint + "/health") else { return }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            status = (response as? HTTPURLResponse)?.statusCode == 200 ? "Ready" : "Error"
        } catch { status = "Offline" }
    }

    func send() async {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let url = URL(string: endpoint + "/v1/chat") else { return }
        transcript.append("You: \(text)")
        message = ""
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["messages": [["role": "user", "content": text]]])
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            transcript.append("NCOM: \((object?["content"] as? String) ?? (object?["error"] as? String) ?? "No response")")
        } catch { transcript.append("NCOM: connection error — \(error.localizedDescription)") }
    }
}
