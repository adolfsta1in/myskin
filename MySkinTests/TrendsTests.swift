import Foundation
import Testing
@testable import MyApp

struct TrendsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// Friday, 2 October 2026.
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 2)) ?? .now }
    private func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today) ?? today }

    @Test func periodIncludesToday() {
        let start = Trends.periodStart(endingOn: today, days: 7, calendar: calendar)
        #expect(start == daysAgo(6))
    }

    @Test func weeklyItchAveragesEachWeek() {
        // Mon 28 Sep … Fri 2 Oct is one week; 21–27 Sep the week before.
        let checkIns = [
            CheckInSample(day: daysAgo(0), itch: 2),
            CheckInSample(day: daysAgo(1), itch: 4),
            CheckInSample(day: daysAgo(7), itch: 8),
            CheckInSample(day: daysAgo(200), itch: 10),
        ]
        let weeks = Trends.weeklyItch(checkIns: checkIns, from: daysAgo(90), to: today, calendar: calendar)
        #expect(weeks.map(\.value) == [8, 3])
        #expect(weeks.last?.date == daysAgo(4))
    }

    @Test func noCheckInsNoPoints() {
        #expect(Trends.weeklyItch(checkIns: [], from: daysAgo(90), to: today, calendar: calendar).isEmpty)
        #expect(Trends.averageItch(checkIns: [], from: daysAgo(90), to: today, calendar: calendar) == nil)
    }

    @Test func averageItchInWindow() {
        let checkIns = [CheckInSample(day: daysAgo(1), itch: 6), CheckInSample(day: daysAgo(2), itch: 2), CheckInSample(day: daysAgo(40), itch: 10)]
        #expect(Trends.averageItch(checkIns: checkIns, from: daysAgo(30), to: today, calendar: calendar) == 4)
    }

    @Test func bsaFollowsTheMapAfterEachDay() {
        let zones = [
            DatedZoneScore(day: daysAgo(120), score: ZoneScore(zoneID: "front.thigh.left", palms: 3, erythema: 2)),
            DatedZoneScore(day: daysAgo(10), score: ZoneScore(zoneID: "front.thigh.right", palms: 2, erythema: 2)),
            DatedZoneScore(day: daysAgo(0), score: ZoneScore(zoneID: "front.thigh.left", palms: 0)),
        ]
        let points = Trends.bsaHistory(zones: zones, from: daysAgo(90), to: today, calendar: calendar)
        // The old left-thigh entry is outside the window but still part of the map.
        #expect(points.map(\.value) == [5, 2])
        #expect(points.map(\.date) == [daysAgo(10), daysAgo(0)])
    }

    @Test func mapOnADay() {
        let zones = [
            DatedZoneScore(day: daysAgo(20), score: ZoneScore(zoneID: "quick.scalp", palms: 1, erythema: 1)),
            DatedZoneScore(day: daysAgo(5), score: ZoneScore(zoneID: "quick.scalp", palms: 0.5, erythema: 2)),
        ]
        #expect(Trends.map(on: daysAgo(10), zones: zones, calendar: calendar).first?.palms == 1)
        #expect(Trends.map(on: today, zones: zones, calendar: calendar).first?.palms == 0.5)
        #expect(Trends.map(on: daysAgo(30), zones: zones, calendar: calendar).isEmpty)
    }

    @Test func scoresAreFilteredAndSorted() {
        let results: [(kind: QuestionnaireKind, date: Date, score: Int)] = [
            (.dlqi, daysAgo(3), 4), (.pest, daysAgo(4), 2), (.dlqi, daysAgo(40), 12), (.dlqi, daysAgo(200), 20),
        ]
        let dlqi = Trends.scores(.dlqi, results: results, from: daysAgo(90), to: today, calendar: calendar)
        #expect(dlqi.map(\.value) == [12, 4])
    }
}
