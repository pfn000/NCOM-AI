import SwiftUI

struct NCOMProfileView: View {
    @AppStorage("ncomProfileName") private var profileName = "Saidie Quinn Newara"
    @AppStorage("ncomProfileRole") private var profileRole = "Owner / Project Lead"

    var body: some View {
        Form {
            Section("Owner") {
                TextField("Display name", text: $profileName)
                TextField("Role", text: $profileRole)
            }
            Section("Project") {
                LabeledContent("Project", value: "NCOM AI")
                LabeledContent("Developer", value: "NCOM Playground")
                LabeledContent("Master Foundation", value: "NCOM Systems")
                LabeledContent("Bundle ID", value: "com.ncom.ai")
            }
            Section("Device") {
                LabeledContent("Development device", value: "iPhone 17 Pro")
                Text("Device identifiers and provisioning secrets are intentionally not displayed in the app profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("NCOM Profile")
    }
}
