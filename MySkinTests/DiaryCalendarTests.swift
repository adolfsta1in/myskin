import Foundation
import Testing
@testable import MyApp

struct DiaryCalendarTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    private func day(_ d: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12)) ?? .now
    }

    @Test func gridStartsOnTheRightWeekday() {
        // 1 October 2026 is a Thursday: Monday-first grid has 3 empty cells.
        let grid = DiaryCalendar.monthGrid(containing: day(15), calendar: calendar)
        #expect(grid.prefix(3).allSatisfy { $0 == nil })
        #expect(grid[3].map { calendar.component(.day, from: $0) } == 1)
        #expect(grid.compactMap(\.self).count == 31)
    }

    @Test func weekdaysFollowFirstWeekday() {
        #expect(DiaryCalendar.weekdaySymbols(calendar: calendar).first == "M")
    }

    @Test func marksCoverOnlyTheMonth() {
        let marks = DiaryCalendar.marks(
            month: day(15),
            checkIns: [CheckInSample(day: day(2), itch: 3), CheckInSample(day: day(5), itch: 8), CheckInSample(day: day(30, month: 9), itch: 2)],
            zones: [],
            photoDays: [day(5)],
            doseDays: [day(2), day(2)],
            calendar: calendar
        )
        let start = { calendar.startOfDay(for: day($0)) }
        #expect(marks.count == 2)
        #expect(marks[start(2)] == DayMark(hasCheckIn: true, dosesDone: 2))
        #expect(marks[start(5)] == DayMark(hasCheckIn: true, hasFlareSign: true, hasPhoto: true))
    }

    @Test func monthSeriesKeepsOnlyLoggedValues() throws {
        let series = DiaryCalendar.series(
            month: day(15),
            entries: [
                CalendarEntry(day: day(3), itch: 6, pain: 2, sleep: nil, humidity: 40, uvIndex: 3),
                CalendarEntry(day: day(1), itch: 2),
                CalendarEntry(day: day(30, month: 9), itch: 9),
            ],
            calendar: calendar
        )
        #expect(series.itch.map(\.value) == [2, 6])
        #expect(series.pain.count == 1)
        #expect(series.sleep.isEmpty)
        #expect(series.hasWeather)
        #expect(series.averageItch == 4)
        #expect(try #require(series.highestItch).value == 6)
    }
}
