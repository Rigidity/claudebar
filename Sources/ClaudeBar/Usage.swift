import Foundation

/// One rate-limit window, with pace computed against a linear burn rate.
struct LimitWindow: Identifiable {
    let id: String
    let title: String
    let usedPercent: Double
    let resetsAt: Date?
    let duration: TimeInterval

    /// How much of the window should be used by now if usage were spread evenly.
    func expectedPercent(at now: Date = Date()) -> Double? {
        guard let resetsAt else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        let elapsed = duration - remaining
        return min(max(elapsed / duration, 0), 1) * 100
    }

    /// Positive = reserve (under pace), negative = deficit (over pace).
    func paceDelta(at now: Date = Date()) -> Double? {
        expectedPercent(at: now).map { $0 - usedPercent }
    }
}

struct UsageSnapshot {
    /// nil when there's no active 5-hour session.
    let session: LimitWindow?
    let weekly: LimitWindow?
    /// nil when the account has no Fable-scoped weekly limit.
    let fableWeekly: LimitWindow?

    private static let fiveHours: TimeInterval = 5 * 3600
    private static let sevenDays: TimeInterval = 7 * 86400

    init(_ response: UsageResponse) {
        let limits = response.limits ?? []

        let sessionLimit = limits.first { $0.group == "session" || $0.kind?.contains("five_hour") == true }
        session = Self.window(id: "session", title: "Session", duration: Self.fiveHours,
                              percent: response.five_hour?.utilization ?? sessionLimit?.percent,
                              resetsAt: response.five_hour?.resets_at ?? sessionLimit?.resets_at)

        let weeklyLimit = limits.first { $0.kind == "weekly_all" }
        weekly = Self.window(id: "weekly", title: "Weekly", duration: Self.sevenDays,
                             percent: response.seven_day?.utilization ?? weeklyLimit?.percent,
                             resetsAt: response.seven_day?.resets_at ?? weeklyLimit?.resets_at)

        let fableLimit = limits.first {
            $0.group == "weekly" && $0.scope?.model?.display_name?.localizedCaseInsensitiveContains("fable") == true
        }
        fableWeekly = Self.window(id: "fable", title: "Fable weekly", duration: Self.sevenDays,
                                  percent: fableLimit?.percent, resetsAt: fableLimit?.resets_at)
    }

    private static func window(id: String, title: String, duration: TimeInterval,
                               percent: Double?, resetsAt: String?) -> LimitWindow? {
        guard let percent else { return nil }
        return LimitWindow(id: id, title: title, usedPercent: percent,
                           resetsAt: resetsAt.flatMap(parseDate), duration: duration)
    }

    /// The API returns microsecond timestamps, which ISO8601DateFormatter can't parse; drop the fraction.
    private static func parseDate(_ string: String) -> Date? {
        let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }
}
