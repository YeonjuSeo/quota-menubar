import Foundation
import AuthenticationServices
import CryptoKit
import AppKit

enum AuthError: LocalizedError {
    case notConfigured
    case cancelled
    case invalidCallback
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OAuth 설정이 완료되지 않았습니다 (Phase 0: client_id 확인 필요)."
        case .cancelled: return "로그인이 취소되었습니다."
        case .invalidCallback: return "로그인 응답을 해석할 수 없습니다."
        case .tokenExchangeFailed: return "토큰 발급에 실패했습니다."
        }
    }
}

/// OAuth 2.0 PKCE login via ASWebAuthenticationSession. The session intercepts
/// the custom `quota://` redirect itself, so no Info.plist URL-scheme
/// registration is required (works from a plain SwiftPM executable too).
@MainActor
final class AuthService: NSObject, ASWebAuthenticationPresentationContextProviding {

    func signIn() async throws -> OAuthToken {
        guard !Config.oauthClientID.isEmpty else { throw AuthError.notConfigured }

        let verifier = Self.randomURLSafe(64)
        let challenge = Self.codeChallenge(for: verifier)

        var comps = URLComponents(url: Config.oauthAuthorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Config.oauthClientID),
            .init(name: "redirect_uri", value: Config.oauthRedirectURI),
            .init(name: "scope", value: Config.oauthScopes),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: Self.randomURLSafe(16))
        ]

        let callback = try await authenticate(url: comps.url!)
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else { throw AuthError.invalidCallback }

        return try await exchange(code: code, verifier: verifier)
    }

    /// Refresh an expired access token.
    func refresh(_ token: OAuthToken) async throws -> OAuthToken {
        guard let refresh = token.refreshToken, !Config.oauthClientID.isEmpty else {
            throw AuthError.tokenExchangeFailed
        }
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": Config.oauthClientID
        ]
        return try await postToken(body)
    }

    // MARK: - ASWebAuthenticationSession

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(
                url: url, callbackURLScheme: Config.oauthRedirectScheme
            ) { callbackURL, error in
                if let callbackURL {
                    cont.resume(returning: callbackURL)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    cont.resume(throwing: AuthError.cancelled)
                } else {
                    cont.resume(throwing: error ?? AuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchange(code: String, verifier: String) async throws -> OAuthToken {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Config.oauthRedirectURI,
            "client_id": Config.oauthClientID,
            "code_verifier": verifier
        ]
        return try await postToken(body)
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

        let refresh = json["refresh_token"] as? String
        var expires: Date?
        if let secs = json["expires_in"] as? Double {
            expires = Date().addingTimeInterval(secs)
        }
        return OAuthToken(accessToken: access, refreshToken: refresh, expiresAt: expires)
    }

    // MARK: - PKCE

    private static func randomURLSafe(_ count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncoded()
    }

    // MARK: - Presentation anchor

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
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
