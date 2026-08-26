import SwiftUI

struct NCOMProfileView: View {
    @AppStorage("ncomProfileName") private var profileName = "Saidie Quinn Newara"
    @AppStorage("ncomProfileRole") private var profileRole = "Owner / Project Lead"
    @AppStorage("ncomProfileHail") private var hailName = "Saidie"

    var body: some View {
        Form {
            Section("Owner") {
                TextField("Display name", text: $profileName)
                TextField("Role", text: $profileRole)
                TextField("Hail name", text: $hailName)
            }
            Section("Project") {
                LabeledContent("Project", value: "NCOM AI")
                LabeledContent("Developer", value: "NCOM Playground")
                LabeledContent("Master Foundation", value: "NCOM Systems")
                LabeledContent("Bundle ID", value: "com.ncom.ai")
                LabeledContent("Bullet ID", value: "NCO: Playground08.26.26JENAAIios")
            }
            Section("Device") {
                LabeledContent("Development device", value: "iPhone 17 Pro")
                Text("Device identifiers, private keys, and provisioning secrets are intentionally not displayed in the profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Private project") {
                Text("NCOM AI is marked NOT FOR PUBLIC RELEASE during private development. Apple signing/distribution is controlled separately from this profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("NCOM Profile")
    }
}
