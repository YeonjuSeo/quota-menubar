import Foundation

/// Central place for the (unofficial) endpoint + OAuth parameters.
///
/// ⚠️ These target Claude's *subscription* usage, for which there is no public
/// API. Values below mirror what the Claude Code CLI uses. They are unverified
/// placeholders where noted — see Phase 0 in the plan: capture a real
/// oauth/usage response and confirm the exact client_id / headers / schema
/// before shipping. Nothing here is transmitted anywhere except Anthropic's
/// own hosts; tokens live only in the local Keychain.
enum Config {
    /// Subscription usage endpoint (same data as Claude Code `/usage`).
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    /// A correct, CLI-shaped User-Agent is REQUIRED or the endpoint 429s
    /// instantly. TODO(Phase 0): confirm the exact current string.
    static let userAgent = "claude-cli/1.0.0 (external, quota-menubar)"

    /// OAuth beta header Claude Code sends with subscription requests.
    static let anthropicBeta = "oauth-2025-04-20"

    // MARK: OAuth (PKCE) — TODO(Phase 0): confirm against Claude Code.
    static let oauthClientID = "" // e.g. "9d1c250a-..." — fill from Phase 0
    static let oauthAuthorizeURL = URL(string: "https://claude.ai/oauth/authorize")!
    static let oauthTokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    static let oauthRedirectScheme = "quota"
    static let oauthRedirectURI = "quota://callback"
    static let oauthScopes = "org:read_usage"

    // MARK: Local credential sources
    /// Keychain generic-password service name Claude Code stores its creds under.
    static let claudeCodeKeychainService = "Claude Code-credentials"
    /// Fallback file path some installs use.
    static var claudeCodeCredentialsFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }

    /// Our own Keychain item for OAuth-login tokens.
    static let ownKeychainService = "com.quota.tokens"
    static let ownKeychainAccount = "oauth"

    static let minPollInterval: Int = 180
}
