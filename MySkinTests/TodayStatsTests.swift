import Foundation
import Testing
@testable import MyApp

struct TodayStatsTests {
    /// Fixed calendar and date so the tests do not depend on the machine's time zone.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 15 October 2026, midday.
    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? .now
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func checkIns(_ offsets: ClosedRange<Int>, itch: Int) -> [CheckInSample] {
        offsets.map { CheckInSample(day: day($0), itch: itch) }
    }

    // MARK: - Itch history

    @Test func emptyHistoryWithoutCheckIns() {
        #expect(TodayStats.itchHistory(endingOn: today, checkIns: [], calendar: calendar).isEmpty)
    }

    @Test func historyKeepsOnlyLastFourteenDaysOldestFirst() {
        let samples = checkIns(-20...0, itch: 4)
        let history = TodayStats.itchHistory(endingOn: today, checkIns: samples, calendar: calendar)
        #expect(history.count == 14)
        #expect(history.first?.date == calendar.startOfDay(for: day(-13)))
        #expect(history.last?.date == calendar.startOfDay(for: today))
    }

    @Test func historySkipsMissingDaysAndUsesRealValues() {
        let samples = [CheckInSample(day: day(-5), itch: 2), CheckInSample(day: day(-1), itch: 8)]
        let history = TodayStats.itchHistory(endingOn: today, checkIns: samples, calendar: calendar)
        #expect(history.map(\.value) == [2, 8])
    }

    @Test func historyIgnoresFutureCheckIns() {
        let samples = [CheckInSample(day: day(1), itch: 5)]
        #expect(TodayStats.itchHistory(endingOn: today, checkIns: samples, calendar: calendar).isEmpty)
    }

    // MARK: - Trend

    @Test func noTrendWithTooFewCheckIns() {
        let samples = checkIns(-1...0, itch: 3) + checkIns(-9...(-8), itch: 6)
        #expect(TodayStats.itchTrend(endingOn: today, checkIns: samples, calendar: calendar) == nil)
    }

    @Test func trendDown() {
        let samples = checkIns(-13...(-7), itch: 6) + checkIns(-6...0, itch: 3)
        #expect(TodayStats.itchTrend(endingOn: today, checkIns: samples, calendar: calendar) == .down)
    }

    @Test func trendUp() {
        let samples = checkIns(-13...(-7), itch: 2) + checkIns(-6...0, itch: 5)
        #expect(TodayStats.itchTrend(endingOn: today, checkIns: samples, calendar: calendar) == .up)
    }

    @Test func trendSteady() {
        let samples = checkIns(-13...(-7), itch: 4) + checkIns(-6...0, itch: 4)
        #expect(TodayStats.itchTrend(endingOn: today, checkIns: samples, calendar: calendar) == .steady)
    }

    // MARK: - Calm days

    @Test func noCalmDaysWithoutCheckIns() {
        #expect(TodayStats.calmDaysThisMonth(on: today, checkIns: [], calendar: calendar) == 0)
    }

    @Test func calmDaysCountOnlyThisMonth() {
        // 1–15 October are in the month; 25–30 September are not.
        let samples = checkIns(-20...0, itch: 2)
        #expect(TodayStats.calmDaysThisMonth(on: today, checkIns: samples, calendar: calendar) == 15)
    }

    @Test func daysWithFlareSignalsAreNotCalm() {
        var samples = checkIns(-9...0, itch: 2)
        samples[9] = CheckInSample(day: today, itch: 8)
        samples[5] = CheckInSample(day: day(-4), itch: 2, newSpots: true)
        #expect(TodayStats.calmDaysThisMonth(on: today, checkIns: samples, calendar: calendar) == 8)
    }

    @Test func missingDaysAreNotCalm() {
        let samples = [CheckInSample(day: day(-10), itch: 1), CheckInSample(day: day(-2), itch: 1)]
        #expect(TodayStats.calmDaysThisMonth(on: today, checkIns: samples, calendar: calendar) == 2)
    }
}
