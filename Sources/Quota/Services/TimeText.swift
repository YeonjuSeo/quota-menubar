import Foundation

/// Korean reset-time phrasing used across the popover.
enum TimeText {
    /// "3시간 8분 후 초기화" / "12분 후 초기화" from a future date.
    static func resetsIn(_ date: Date?, now: Date = Date()) -> String {
        guard let date, date > now else { return "곧 초기화" }
        let secs = Int(date.timeIntervalSince(now))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)시간 \(m)분 후 초기화" }
        return "\(m)분 후 초기화"
    }

    /// "일요일 21:59 초기화" — absolute weekday + time.
    static func resetsAt(_ date: Date?) -> String {
        guard let date else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "EEEE HH:mm"
        return "\(fmt.string(from: date)) 초기화"
    }

    /// "방금 업데이트" / "12분 전 업데이트" from a past date. Empty for the
    /// sentinel `.distantPast` (sample data).
    static func updatedAgo(_ date: Date, now: Date = Date()) -> String {
        guard date != .distantPast else { return "" }
        let secs = max(0, Int(now.timeIntervalSince(date)))
        if secs < 60 { return "방금 업데이트" }
        if secs < 3600 { return "\(secs / 60)분 전 업데이트" }
        return "\(secs / 3600)시간 전 업데이트"
    }
}
