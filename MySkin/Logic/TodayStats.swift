import Foundation

/// Direction of itch over the last week compared with the week before.
enum ItchTrend: Equatable {
    case down
    case steady
    case up
}

/// Numbers for the Today cards (itch chart, trend badge, calm days), built from stored check-ins.
enum TodayStats {
    enum Threshold {
        /// Days shown in the itch chart, today included.
        static let chartDays = 14
        /// Check-ins in the chart window needed to draw the chart.
        static let minChartPoints = 2
        /// Length of each half used for the trend.
        static let trendWindowDays = 7
        /// Check-ins needed in each half for a trend.
        static let minTrendCheckIns = 3
        /// Change of the weekly average (points) that counts as a trend.
        static let trendDelta = 1.0
    }

    /// One bar per day with a check-in in the last `days` days, oldest first. Days without a check-in are skipped.
    static func itchHistory(
        endingOn date: Date,
        checkIns: [CheckInSample],
        days: Int = Threshold.chartDays,
        calendar: Calendar = .current
    ) -> [DayValue] {
        let today = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }
        var byDay: [Date: Int] = [:]
        for checkIn in checkIns {
            let day = calendar.startOfDay(for: checkIn.day)
            if day >= start && day <= today {
                byDay[day] = checkIn.itch
            }
        }
        return byDay.keys.sorted().compactMap { day in
            byDay[day].map { DayValue(date: day, value: Double($0)) }
        }
    }

    /// Average itch of the last `trendWindowDays` days vs the same window before it.
    /// `nil` when either window has too few check-ins.
    static func itchTrend(
        endingOn date: Date,
        checkIns: [CheckInSample],
        calendar: Calendar = .current
    ) -> ItchTrend? {
        let window = Threshold.trendWindowDays
        let history = itchHistory(endingOn: date, checkIns: checkIns, days: window * 2, calendar: calendar)
        let today = calendar.startOfDay(for: date)
        guard let recentStart = calendar.date(byAdding: .day, value: -(window - 1), to: today) else { return nil }
        let recent = history.filter { $0.date >= recentStart }.map(\.value)
        let previous = history.filter { $0.date < recentStart }.map(\.value)
        guard recent.count >= Threshold.minTrendCheckIns, previous.count >= Threshold.minTrendCheckIns else { return nil }

        let delta = recent.reduce(0, +) / Double(recent.count) - previous.reduce(0, +) / Double(previous.count)
        if delta <= -Threshold.trendDelta { return .down }
        if delta >= Threshold.trendDelta { return .up }
        return .steady
    }

    /// Days of the current month, up to `date`, that have a check-in and no flare signal
    /// (`FlareDetector.signals`). Days without a check-in are not counted: nothing is known about them.
    static func calmDaysThisMonth(
        on date: Date,
        checkIns: [CheckInSample],
        zones: [DatedZoneScore] = [],
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: date)
        guard let monthStart = calendar.dateInterval(of: .month, for: today)?.start else { return 0 }
        let days = Set(checkIns.map { calendar.startOfDay(for: $0.day) }.filter { $0 >= monthStart && $0 <= today })
        let pastCheckIns = checkIns.filter { calendar.startOfDay(for: $0.day) <= today }
        return days.filter { day in
            FlareDetector.signals(on: day, checkIns: pastCheckIns, zones: zones, calendar: calendar).isEmpty
        }.count
    }
}
