import Foundation

enum APIError: Error, Equatable {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case badResponse
}

/// Calls the (unofficial) subscription usage endpoint and maps the response
/// into a `UsageSnapshot`. The response schema is undocumented, so decoding is
/// deliberately tolerant: it probes several candidate key paths and fills what
/// it can. Confirm/tighten in Phase 0 once a real payload is captured.
struct UsageAPIClient {

    func fetch(token: OAuthToken) async throws -> UsageSnapshot {
        var req = URLRequest(url: Config.usageURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(Config.userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(Config.anthropicBeta, forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.badResponse
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }

        switch http.statusCode {
        case 200:
            return try Self.parse(data)
        case 401, 403:
            throw APIError.unauthorized
        case 429:
            let retry = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            throw APIError.rateLimited(retryAfter: retry)
        default:
            throw APIError.http(http.statusCode)
        }
    }

    // MARK: - Tolerant decoding

    static func parse(_ data: Data) throws -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.badResponse
        }

        // 5-hour window
        let five = firstDict(in: root, keys: ["five_hour", "fiveHour", "session", "five_hour_limit"])
        let fivePct = percent(in: five ?? root, keys: ["utilization", "percent", "used_pct", "pct"])
        let fiveReset = date(in: five ?? root, keys: ["resets_at", "reset_at", "resetsAt", "reset"])

        // Weekly (all models)
        let weekly = firstDict(in: root, keys: ["seven_day", "sevenDay", "weekly", "week"])
        let weeklyPct = percent(in: weekly ?? root,
                                keys: ["utilization", "percent", "all_models", "allModels", "pct"])
        let weeklyReset = date(in: weekly ?? root, keys: ["resets_at", "reset_at", "resetsAt", "reset"])

        // Per-model rows
        var models: [ModelUsage] = []
        if let arr = firstArray(in: weekly ?? root, keys: ["models", "per_model", "by_model"]) {
            for item in arr {
                guard let d = item as? [String: Any] else { continue }
                let name = (d["name"] as? String) ?? (d["model"] as? String) ?? "모델"
                let pct = percent(in: d, keys: ["utilization", "percent", "pct"])
                models.append(ModelUsage(name: prettyModelName(name), percent: pct))
            }
        }

        // Peak / rate state
        let isPeak = (root["is_peak"] as? Bool)
            ?? ((firstDict(in: root, keys: ["rate", "rate_state"])?["is_peak"]) as? Bool)
            ?? false
        let peakDate = date(in: root, keys: ["peak_starts_at", "peakStartsAt", "next_peak_at"])

        return UsageSnapshot(
            fiveHourPercent: fivePct,
            fiveHourResetText: TimeText.resetsIn(fiveReset),
            weeklyAllPercent: weeklyPct,
            weeklyResetText: TimeText.resetsAt(weeklyReset),
            models: models,
            isPeak: isPeak,
            rateLabel: isPeak ? "피크" : "표준 요금",
            peakText: TimeText.peakIn(peakDate),
            lastUpdated: Date()
        )
    }

    // MARK: helpers

    private static func firstDict(in root: [String: Any], keys: [String]) -> [String: Any]? {
        for k in keys { if let d = root[k] as? [String: Any] { return d } }
        return nil
    }
    private static func firstArray(in root: [String: Any], keys: [String]) -> [Any]? {
        for k in keys { if let a = root[k] as? [Any] { return a } }
        return nil
    }

    /// Extracts a 0…100 int. Accepts 0…1 fractions and 0…100 values.
    private static func percent(in root: [String: Any], keys: [String]) -> Int {
        for k in keys {
            if let n = root[k] as? Double { return normalize(n) }
            if let n = root[k] as? Int { return normalize(Double(n)) }
        }
        return 0
    }
    private static func normalize(_ n: Double) -> Int {
        let v = n <= 1.0 ? n * 100 : n
        return max(0, min(100, Int(v.rounded())))
    }

    private static func date(in root: [String: Any], keys: [String]) -> Date? {
        for k in keys {
            if let s = root[k] as? String {
                if let d = ISO8601DateFormatter().date(from: s) { return d }
            }
            if let ms = root[k] as? Double {
                return Date(timeIntervalSince1970: ms > 1e12 ? ms / 1000 : ms)
            }
        }
        return nil
    }

    private static func prettyModelName(_ raw: String) -> String {
        let r = raw.lowercased()
        if r.contains("opus") { return "Opus" }
        if r.contains("fable") { return "Fable 5" }
        if r.contains("sonnet") { return "Sonnet" }
        if r.contains("haiku") { return "Haiku" }
        return raw
    }
}
