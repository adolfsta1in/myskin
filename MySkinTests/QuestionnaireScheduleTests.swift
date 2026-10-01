import Foundation
import Testing
@testable import MyApp

struct QuestionnaireScheduleTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 10)) ?? .now }
    private func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now) ?? now }

    @Test func cleanInstallHasBothDue() {
        let none: [(kind: QuestionnaireKind, date: Date)] = []
        #expect(QuestionnaireSchedule.due(now: now, results: none, calendar: calendar) == [.dlqi, .pest])
    }

    @Test func takenTodayIsNotDue() {
        let results: [(kind: QuestionnaireKind, date: Date)] = [(.dlqi, now), (.pest, now)]
        #expect(QuestionnaireSchedule.due(now: now, results: results, calendar: calendar).isEmpty)
    }

    @Test func dlqiIsDueAfterThirtyDays() {
        #expect(!QuestionnaireSchedule.isDue(.dlqi, lastTaken: daysAgo(29), now: now, calendar: calendar))
        #expect(QuestionnaireSchedule.isDue(.dlqi, lastTaken: daysAgo(30), now: now, calendar: calendar))
    }

    @Test func pestIsDueAfterThreeMonths() {
        #expect(!QuestionnaireSchedule.isDue(.pest, lastTaken: daysAgo(60), now: now, calendar: calendar))
        #expect(QuestionnaireSchedule.isDue(.pest, lastTaken: daysAgo(91), now: now, calendar: calendar))
    }

    @Test func latestResultCounts() {
        let results: [(kind: QuestionnaireKind, date: Date)] = [(.dlqi, daysAgo(5)), (.dlqi, daysAgo(80)), (.pest, daysAgo(100))]
        #expect(QuestionnaireSchedule.due(now: now, results: results, calendar: calendar) == [.pest])
    }
}
