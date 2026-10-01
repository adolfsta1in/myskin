import Foundation

/// One point of a chart: a day (or week start) and a value.
struct DayValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Series for the Insights charts and the doctor report, built from stored records.
enum Trends {
    /// Default Insights window, in days.
    static let periodDays = 91

    /// Start of the day `days - 1` days before `date`, so the window includes `date`'s day.
    static func periodStart(endingOn date: Date, days: Int = periodDays, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
    }

    /// Weekly average itch, one point per week that has check-ins, oldest first.
    /// The point's date is the start of the week.
    static func weeklyItch(
        checkIns: [CheckInSample],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [DayValue] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var weeks: [Date: [Int]] = [:]
        for checkIn in checkIns {
            let day = calendar.startOfDay(for: checkIn.day)
            guard day >= first, day <= last,
                  let week = calendar.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            weeks[week, default: []].append(checkIn.itch)
        }
        return weeks.keys.sorted().compactMap { week in
            guard let values = weeks[week], !values.isEmpty else { return nil }
            return DayValue(date: week, value: Double(values.reduce(0, +)) / Double(values.count))
        }
    }

    /// Average itch over the check-ins in a window; nil without check-ins.
    static func averageItch(checkIns: [CheckInSample], from start: Date, to end: Date, calendar: Calendar = .current) -> Double? {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let values = checkIns
            .filter { calendar.startOfDay(for: $0.day) >= first && calendar.startOfDay(for: $0.day) <= last }
            .map(\.itch)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// BSA after each assessment day (each zone keeps its latest score), oldest first.
    /// Only days in the window are returned, but earlier assessments still count for the map state.
    static func bsaHistory(
        zones: [DatedZoneScore],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [DayValue] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let sorted = zones.sorted { $0.day < $1.day }
        var map: [String: ZoneScore] = [:]
        var points: [DayValue] = []
        var index = sorted.startIndex
        while index < sorted.endIndex {
            let day = calendar.startOfDay(for: sorted[index].day)
            while index < sorted.endIndex && calendar.startOfDay(for: sorted[index].day) == day {
                map[sorted[index].score.zoneID] = sorted[index].score
                index += 1
            }
            if day >= first && day <= last {
                points.append(DayValue(date: day, value: SeverityCalculator.snapshot(for: Array(map.values)).bsa))
            }
        }
        return points
    }

    /// Body map as it was at the end of `date` (latest score of each zone up to that day).
    static func map(on date: Date, zones: [DatedZoneScore], calendar: Calendar = .current) -> [ZoneScore] {
        let last = calendar.startOfDay(for: date)
        var map: [String: ZoneScore] = [:]
        for entry in zones.sorted(by: { $0.day < $1.day }) where calendar.startOfDay(for: entry.day) <= last {
            map[entry.score.zoneID] = entry.score
        }
        return Array(map.values)
    }

    /// Questionnaire scores in the window, oldest first.
    static func scores(
        _ kind: QuestionnaireKind,
        results: [(kind: QuestionnaireKind, date: Date, score: Int)],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [DayValue] {
        let first = calendar.startOfDay(for: start)
        return results
            .filter { $0.kind == kind && $0.date >= first && $0.date <= end }
            .sorted { $0.date < $1.date }
            .map { DayValue(date: $0.date, value: Double($0.score)) }
    }
}

extension QuestionnaireResult {
    var trendPoint: (kind: QuestionnaireKind, date: Date, score: Int) { (kind, date, score) }
}
