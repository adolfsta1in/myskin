import Foundation

/// What a calendar day has: shown as dots in the month grid.
struct DayMark: Equatable, Sendable {
    var hasCheckIn = false
    /// Any `FlareDetector` signal on that day.
    var hasFlareSign = false
    var hasPhoto = false
    var hasZoneAssessment = false
    var dosesDone = 0

    var isEmpty: Bool { self == DayMark() }
}

/// Check-in fields the month charts use.
struct CalendarEntry: Hashable, Sendable {
    let day: Date
    let itch: Int
    var pain: Int?
    var sleep: Int?
    var humidity: Double?
    var uvIndex: Double?
}

extension DailyCheckIn {
    var calendarEntry: CalendarEntry {
        CalendarEntry(day: day, itch: itch, pain: pain, sleep: sleep, humidity: humidity, uvIndex: uvIndex)
    }
}

/// One month of check-ins as chart series, oldest first. Days without a value are left out.
struct MonthSeries {
    var itch: [DayValue] = []
    var pain: [DayValue] = []
    var sleep: [DayValue] = []
    var humidity: [DayValue] = []
    var uvIndex: [DayValue] = []

    var daysLogged: Int { itch.count }
    var averageItch: Double? { itch.isEmpty ? nil : itch.map(\.value).reduce(0, +) / Double(itch.count) }
    var highestItch: DayValue? { itch.max { $0.value < $1.value } }
    var hasWeather: Bool { !humidity.isEmpty || !uvIndex.isEmpty }
}

/// Month grid and per-day marks for the diary calendar.
enum DiaryCalendar {
    /// Days of the month as grid cells, with nil padding before the first day so that
    /// columns line up with `calendar.firstWeekday`.
    static func monthGrid(containing date: Date, calendar: Calendar = .current) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let first = interval.start
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let dates: [Date?] = days.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: first)
        }
        return Array(repeating: nil, count: leading) + dates
    }

    /// Short weekday symbols starting with `calendar.firstWeekday`.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Marks for every day of the month that has something logged.
    static func marks(
        month date: Date,
        checkIns: [CheckInSample],
        zones: [DatedZoneScore],
        photoDays: [Date],
        doseDays: [Date],
        calendar: Calendar = .current
    ) -> [Date: DayMark] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [:] }
        func inMonth(_ day: Date) -> Date? {
            let start = calendar.startOfDay(for: day)
            return interval.contains(start) ? start : nil
        }

        var marks: [Date: DayMark] = [:]
        for checkIn in checkIns {
            guard let day = inMonth(checkIn.day) else { continue }
            marks[day, default: DayMark()].hasCheckIn = true
        }
        for zone in zones {
            guard let day = inMonth(zone.day) else { continue }
            marks[day, default: DayMark()].hasZoneAssessment = true
        }
        for photoDay in photoDays {
            guard let day = inMonth(photoDay) else { continue }
            marks[day, default: DayMark()].hasPhoto = true
        }
        for doseDay in doseDays {
            guard let day = inMonth(doseDay) else { continue }
            marks[day, default: DayMark()].dosesDone += 1
        }
        for day in marks.keys where marks[day]?.hasCheckIn == true || marks[day]?.hasZoneAssessment == true {
            if !FlareDetector.signals(on: day, checkIns: checkIns, zones: zones, calendar: calendar).isEmpty {
                marks[day]?.hasFlareSign = true
            }
        }
        return marks
    }

    static func series(month date: Date, entries: [CalendarEntry], calendar: Calendar = .current) -> MonthSeries {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return MonthSeries() }
        // One entry per day (the store guarantees it; keep the last if not).
        var byDay: [Date: CalendarEntry] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.day)
            if interval.contains(day) { byDay[day] = entry }
        }
        var series = MonthSeries()
        for day in byDay.keys.sorted() {
            guard let entry = byDay[day] else { continue }
            series.itch.append(DayValue(date: day, value: Double(entry.itch)))
            if let pain = entry.pain { series.pain.append(DayValue(date: day, value: Double(pain))) }
            if let sleep = entry.sleep { series.sleep.append(DayValue(date: day, value: Double(sleep))) }
            if let humidity = entry.humidity { series.humidity.append(DayValue(date: day, value: humidity)) }
            if let uv = entry.uvIndex { series.uvIndex.append(DayValue(date: day, value: uv)) }
        }
        return series
    }

    /// Whether `date` is in the same day as `day`.
    static func isSameDay(_ date: Date, as day: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: day)
    }
}
