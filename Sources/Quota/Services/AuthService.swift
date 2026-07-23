import Foundation
import CryptoKit
import AppKit

enum AuthError: LocalizedError {
    case notConfigured
    case cancelled
    case invalidCallback
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "OAuth 설정이 없습니다."
        case .cancelled: return "로그인이 취소되었습니다."
        case .invalidCallback: return "붙여넣은 코드를 해석할 수 없습니다."
        case .tokenExchangeFailed: return "토큰 발급에 실패했습니다."
        }
    }
}

/// OAuth 2.0 Authorization Code + PKCE, using Claude Code's own client.
///
/// Claude Code's registered redirect is a console callback page that displays
/// `code#state` for the user to copy — there is no custom-scheme interception.
/// So sign-in opens the browser and prompts the user to paste the code back
/// (the same flow other Claude-subscription tools use).
@MainActor
final class AuthService: NSObject {

    func signIn() async throws -> OAuthToken {
        guard !Config.oauthClientID.isEmpty else { throw AuthError.notConfigured }

        let verifier = Self.randomURLSafe(64)
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomURLSafe(16)

        var comps = URLComponents(url: Config.oauthAuthorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "code", value: "true"),
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Config.oauthClientID),
            .init(name: "redirect_uri", value: Config.oauthRedirectURI),
            .init(name: "scope", value: Config.oauthScopes),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state)
        ]
        NSWorkspace.shared.open(comps.url!)

        guard let pasted = promptForCode() else { throw AuthError.cancelled }
        // The console callback shows "CODE#STATE"; take the code part.
        let code = pasted.split(separator: "#").first.map(String.init) ?? pasted
        guard !code.isEmpty else { throw AuthError.invalidCallback }

        return try await exchange(code: code, verifier: verifier, state: state)
    }

    func refresh(_ token: OAuthToken) async throws -> OAuthToken {
        guard let refresh = token.refreshToken, !Config.oauthClientID.isEmpty else {
            throw AuthError.tokenExchangeFailed
        }
        return try await postToken([
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": Config.oauthClientID
        ])
    }

    // MARK: - Manual code entry

    private func promptForCode() -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Claude 계정 로그인"
        alert.informativeText = "열린 브라우저에서 로그인·승인한 뒤,\n표시된 인증 코드를 아래에 붙여넣으세요."
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "인증 코드 붙여넣기"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn
            ? field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
    }

    // MARK: - Token exchange

    private func exchange(code: String, verifier: String, state: String) async throws -> OAuthToken {
        try await postToken([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Config.oauthRedirectURI,
            "client_id": Config.oauthClientID,
            "code_verifier": verifier,
            "state": state
        ])
    }

    private func postToken(_ body: [String: String]) async throws -> OAuthToken {
        var req = URLRequest(url: Config.oauthTokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Config.userAgent, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String
        else { throw AuthError.tokenExchangeFailed }

        var expires: Date?
        if let secs = json["expires_in"] as? Double { expires = Date().addingTimeInterval(secs) }
        return OAuthToken(accessToken: access,
                          refreshToken: json["refresh_token"] as? String,
                          expiresAt: expires)
    }

    // MARK: - PKCE

    private static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded()
    }
    private static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
