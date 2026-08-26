import AuthenticationServices
import SwiftUI

/// NCOM's account broker keeps the user inside the app while preferring
/// platform authentication (passkeys / Password AutoFill / OAuth) and using
/// a remote browser only as an explicit fallback. NCOM never imports or
/// exports the user's iCloud Keychain password database.
struct NCOMIdentityView: View {
    @StateObject private var microsoft = NCOMMicrosoftAuth()
    @State private var showMicrosoft = false
    @State private var remoteURL = ""
    @State private var status = "Ready"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NCOMMetrics.sectionSpacing) {
                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("NCOM Identity", systemImage: "person.badge.key.fill")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Connect accounts without handing NCOM your password database. NCOM prefers passkeys, Password AutoFill and OAuth, with Keychain-backed tokens for programs.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            identityChip("Passkeys", systemImage: "key.fill")
                            identityChip("Password AutoFill", systemImage: "lock.fill")
                            identityChip("Keychain", systemImage: "checkmark.shield.fill")
                        }
                    }
                }

                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Microsoft / Outlook", systemImage: "envelope.fill")
                                .font(.headline)
                            Spacer()
                            Circle()
                                .fill(microsoft.authenticated ? .green : .secondary)
                                .frame(width: 9, height: 9)
                        }

                        Text(microsoft.authenticated
                             ? "Connected. Outlook programs can use the protected account session."
                             : "Not connected. The sign-in session stays in Apple's authentication UI and returns to NCOM.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button(microsoft.authenticated ? "Microsoft Connected" : "Connect Microsoft") {
                            showMicrosoft = true
                        }
                        .buttonStyle(NCOMGlassButtonStyle(prominent: !microsoft.authenticated))
                        .disabled(microsoft.authenticated)
                    }
                }

                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Use iPhone Passwords / Passkey", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.headline)
                        Text("For websites that support Password AutoFill or passkeys, NCOM can present the service's normal authentication session. Your actual iCloud Keychain database is never exported to NCOM.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("The service must support the appropriate Apple authentication mechanism; iOS does not provide third-party apps with a bulk 'import all Apple Passwords' API.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Remote Browser Fallback", systemImage: "arrow.up.forward.app")
                            .font(.headline)
                        Text("If a service cannot authenticate inside NCOM, send only its authorization URL to an authorized NCOM Desktop/browser. The browser returns an OAuth authorization result to NCOM; passwords, cookies and session databases are never copied back.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        TextField("Authorization URL", text: $remoteURL)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()

                        HStack {
                            Button("Send to NCOM Desktop") {
                                status = "Authorization handoff queued"
                            }
                            .buttonStyle(NCOMGlassButtonStyle(prominent: true))
                            .disabled(!isHTTPURL)

                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Security boundary", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                        Text("Programs receive scoped capabilities (for example, Outlook: Send Mail), not raw passwords. Tokens remain in the iOS Keychain and can be revoked from this screen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(NCOMBackground())
        .navigationTitle("Identity")
        .sheet(isPresented: $showMicrosoft) {
            NCOMMicrosoftSignInView(auth: microsoft)
        }
    }

    private var isHTTPURL: Bool {
        guard let url = URL(string: remoteURL) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    private func identityChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.white.opacity(0.055), in: Capsule())
    }
}

struct NCOMMicrosoftSignInView: View {
    @ObservedObject var auth: NCOMMicrosoftAuth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                NCOMLogo(size: 38)
                Text("Connect Microsoft")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("NCOM will use Apple's secure web authentication session. If your iPhone already knows your Microsoft credentials or passkey, use them there.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Sign in with Microsoft") {
                    Task {
                        do {
                            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                                  let window = scene.windows.first(where: { $0.isKeyWindow }) else {
                                throw NSError(domain: "NCOM.Identity", code: 10, userInfo: [NSLocalizedDescriptionKey: "No presentation window is available."])
                            }
                            try await auth.signIn(anchor: window)
                            dismiss()
                        } catch {
                            // The parent UI can expose the error in a later revision.
                        }
                    }
                }
                .buttonStyle(NCOMGlassButtonStyle(prominent: true))

                Spacer()
            }
            .padding(24)
            .background(NCOMBackground())
            .navigationTitle("Authentication")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
