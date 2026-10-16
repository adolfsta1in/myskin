import Foundation

/// When the weather may be fetched. Weather providers bill or cap by request (WeatherKit:
/// 500,000 calls a month on the free tier), so the app asks only while the user has Today open,
/// reuses a fresh reading, waits after a failure and has a hard daily cap per device.
nonisolated enum WeatherRequestPolicy {
    /// A reading younger than this is reused.
    static let freshFor: TimeInterval = 60 * 60
    /// After a failed request, automatic refreshes wait this long (the «Try again» button doesn't).
    static let retryAfterFailure: TimeInterval = 5 * 60
    /// Hard cap per device and calendar day, whatever happens on screen.
    static let maxPerDay = 12

    /// Requests made today; persisted so relaunching the app doesn't reset it.
    struct DailyCount: Equatable {
        var day: Date
        var count: Int

        /// The count for `now`'s day (zero on a new day).
        func current(on now: Date, calendar: Calendar = .current) -> Int {
            calendar.isDate(day, inSameDayAs: now) ? count : 0
        }

        /// Counts one more request made at `now`.
        func adding(on now: Date, calendar: Calendar = .current) -> DailyCount {
            DailyCount(day: calendar.startOfDay(for: now), count: current(on: now, calendar: calendar) + 1)
        }
    }

    /// Whether a new request may go out now.
    /// - Parameters:
    ///   - lastSuccess: when the reading on screen was fetched (nil if there is none).
    ///   - lastFailure: when the last request failed (nil if it didn't).
    ///   - isManual: the user tapped «Try again» — skips the wait after a failure, not the cap.
    static func mayRequest(
        now: Date,
        lastSuccess: Date?,
        lastFailure: Date?,
        isManual: Bool,
        daily: DailyCount?,
        calendar: Calendar = .current
    ) -> Bool {
        if let lastSuccess, now.timeIntervalSince(lastSuccess) < freshFor { return false }
        if !isManual, let lastFailure, now.timeIntervalSince(lastFailure) < retryAfterFailure { return false }
        return (daily?.current(on: now, calendar: calendar) ?? 0) < maxPerDay
    }
}
