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

    /// Real (undocumented) schema, confirmed from community reverse-engineering:
    /// ```
    /// { "five_hour":  { "utilization": 33.0, "resets_at": "ISO8601" },
    ///   "seven_day":  { "utilization": 13.0, "resets_at": "ISO8601" },
    ///   "seven_day_opus": null,
    ///   "seven_day_sonnet": { "utilization": 1.0, "resets_at": "ISO8601" },
    ///   "extra_usage": { "is_enabled": false, "used_credits": null, ... } }
    /// ```
    /// `utilization` is already a 0…100 percentage (1.0 == 1%, NOT a fraction).
    static func parse(_ data: Data) throws -> UsageSnapshot {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.badResponse
        }

        let five = root["five_hour"] as? [String: Any]
        let weekly = root["seven_day"] as? [String: Any]

        // Per-model weekly rows: any non-null "seven_day_<model>" object.
        var models: [ModelUsage] = []
        for (key, value) in root where key.hasPrefix("seven_day_") {
            guard let d = value as? [String: Any] else { continue } // skip nulls
            let pct = percentInt(d["utilization"])
            let name = prettyModelName(String(key.dropFirst("seven_day_".count)))
            models.append(ModelUsage(name: name, percent: pct))
        }
        models.sort { $0.name < $1.name }

        return UsageSnapshot(
            fiveHourPercent: percentInt(five?["utilization"]),
            fiveHourResetText: TimeText.resetsIn(isoDate(five?["resets_at"])),
            weeklyAllPercent: percentInt(weekly?["utilization"]),
            weeklyResetText: TimeText.resetsAt(isoDate(weekly?["resets_at"])),
            models: models,
            // The usage endpoint carries no peak-window info; leave neutral.
            isPeak: false,
            rateLabel: "표준 요금",
            peakText: "",
            lastUpdated: Date()
        )
    }

    // MARK: helpers

    /// `utilization` is a 0…100 percentage already — round + clamp, no scaling.
    private static func percentInt(_ any: Any?) -> Int {
        let v: Double
        if let d = any as? Double { v = d }
        else if let i = any as? Int { v = Double(i) }
        else { return 0 }
        return max(0, min(100, Int(v.rounded())))
    }

    private static func isoDate(_ any: Any?) -> Date? {
        guard let s = any as? String else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFrac.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    private static func prettyModelName(_ raw: String) -> String {
        let r = raw.lowercased()
        if r.contains("opus") { return "Opus" }
        if r.contains("fable") { return "Fable 5" }
        if r.contains("sonnet") { return "Sonnet" }
        if r.contains("haiku") { return "Haiku" }
        return raw.capitalized
    }
}
