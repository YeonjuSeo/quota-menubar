import Foundation

/// One weekly per-model usage row (e.g. "Fable 5" → 25%).
struct ModelUsage: Identifiable, Equatable {
    let name: String
    let percent: Int
    var id: String { name }
}

/// Normalized usage snapshot that drives every view. Populated from the
/// oauth/usage response, or from sample data when signed out.
struct UsageSnapshot: Equatable {
    /// 5-hour rolling window usage, 0…100.
    var fiveHourPercent: Int
    /// Human text like "3시간 8분 후 초기화".
    var fiveHourResetText: String

    /// Weekly all-models usage, 0…100.
    var weeklyAllPercent: Int
    /// e.g. "일요일 21:59 초기화".
    var weeklyResetText: String
    /// Per-model weekly rows (Opus/Fable/…).
    var models: [ModelUsage]

    /// Rate window state.
    var isPeak: Bool
    var rateLabel: String       // "표준 요금" / "피크"
    var peakText: String        // "10시간 59분 후 피크"

    var lastUpdated: Date

    static let sample = UsageSnapshot(
        fiveHourPercent: 19,
        fiveHourResetText: "3시간 8분 후 초기화",
        weeklyAllPercent: 19,
        weeklyResetText: "일요일 21:59 초기화",
        models: [ModelUsage(name: "Fable 5", percent: 25)],
        isPeak: false,
        rateLabel: "표준 요금",
        peakText: "10시간 59분 후 피크",
        lastUpdated: .distantPast
    )
}

/// Where the current data came from — drives the popover's status/footer.
enum DataSource: Equatable {
    case sample                 // signed out; showing placeholder numbers
    case claudeCodeCLI          // token borrowed from ~/.claude / Keychain
    case oauthLogin             // signed in via the app's own OAuth
}

/// Auth/connection state for the popover.
enum LoadState: Equatable {
    case signedOut
    case loading
    case loaded(DataSource)
    case rateLimited(retryAfter: TimeInterval?)
    case error(String)
}
