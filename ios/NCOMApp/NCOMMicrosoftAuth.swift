import Foundation
import AuthenticationServices
import CryptoKit
import Security

final class NCOMKeychain: @unchecked Sendable {
    static let shared = NCOMKeychain()
    private init() {}
    func save(_ value: Data, key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = value
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
    func load(_ key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }
    func delete(_ key: String) { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary) }
}

@MainActor
final class NCOMMicrosoftAuth: ObservableObject {
    @Published private(set) var authenticated = false
    private let accessKey = "ncom.microsoft.access-token"
    private let refreshKey = "ncom.microsoft.refresh-token"
    private let verifierKey = "ncom.microsoft.pkce-verifier"
    private var session: ASWebAuthenticationSession?
    private var provider: NCOMAuthPresentationProvider?

    static let redirectURI = "com.ncom.ai://microsoft-auth"
    static let scopes = "openid profile offline_access User.Read Mail.Send"
    static var clientID: String? { Bundle.main.object(forInfoDictionaryKey: "MICROSOFT_CLIENT_ID") as? String }

    init() { authenticated = NCOMKeychain.shared.load(accessKey) != nil }

    func signIn(anchor: ASPresentationAnchor) async throws {
        guard let clientID = Self.clientID, !clientID.isEmpty, clientID != "CONFIGURE_IN_PRIVATE_BUILD" else {
            throw NSError(domain: "NCOM.Microsoft", code: 1, userInfo: [NSLocalizedDescriptionKey: "MICROSOFT_CLIENT_ID is not configured in this private build."])
        }
        let verifier = Data((0..<64).map { _ in UInt8.random(in: 0...255) }).base64URLEncodedString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        let state = Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64URLEncodedString()
        NCOMKeychain.shared.save(Data(verifier.utf8), key: verifierKey)

        var components = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID), URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI), URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Self.scopes), URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge), URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        let callback = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let auth = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: "com.ncom.ai") { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? NSError(domain: "NCOM.Microsoft", code: 2)) }
            }
            let presentationProvider = NCOMAuthPresentationProvider(anchor: anchor)
            auth.presentationContextProvider = presentationProvider
            auth.prefersEphemeralWebBrowserSession = false
            self.provider = presentationProvider
            self.session = auth
            auth.start()
        }

        guard let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            throw NSError(domain: "NCOM.Microsoft", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid Microsoft callback."])
        }
        try await exchange(code: code, verifier: verifier, clientID: clientID)
        session = nil
        provider = nil
    }

    func accessToken() -> String? { NCOMKeychain.shared.load(accessKey).flatMap { String(data: $0, encoding: .utf8) } }

    private func exchange(code: String, verifier: String, clientID: String) async throws {
        var request = URLRequest(url: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let values = ["client_id": clientID, "grant_type": "authorization_code", "code": code, "redirect_uri": Self.redirectURI, "code_verifier": verifier]
        request.httpBody = values.map { "\($0.key)=\($0.value.urlFormEncoded)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "NCOM.Microsoft", code: 4, userInfo: [NSLocalizedDescriptionKey: "Microsoft token exchange failed."])
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        NCOMKeychain.shared.save(Data(token.accessToken.utf8), key: accessKey)
        if let refresh = token.refreshToken { NCOMKeychain.shared.save(Data(refresh.utf8), key: refreshKey) }
        authenticated = true
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        enum CodingKeys: String, CodingKey { case accessToken = "access_token"; case refreshToken = "refresh_token" }
    }
}

private final class NCOMAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}

struct NCOMOutlookProgram {
    static func sendMail(token: String, to: String, subject: String, body: String) async throws {
        var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/sendMail")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["message": ["subject": subject, "body": ["contentType": "Text", "content": body], "toRecipients": [["emailAddress": ["address": to]]]]])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "NCOM.Outlook", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

private extension String {
    var urlFormEncoded: String { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self }
}
private extension Data {
    func base64URLEncodedString() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}