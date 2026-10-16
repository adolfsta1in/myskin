import Foundation
import Testing
@testable import MySkin

struct QuestionnaireScheduleTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 10)) ?? .now }
    private func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now) ?? now }

    @Test func cleanInstallHasBothDue() {
        let none: [(kind: QuestionnaireKind, date: Date)] = []
        #expect(QuestionnaireSchedule.due(now: now, results: none, calendar: calendar) == [.skinImpact, .jointCheck])
    }

    @Test func diagnosedArthritisSkipsJointCheck() {
        let none: [(kind: QuestionnaireKind, date: Date)] = []
        #expect(QuestionnaireSchedule.due(now: now, results: none, arthritis: .diagnosed, calendar: calendar) == [.skinImpact])
        for status in [ArthritisStatus.suspected, .no, .unsure] {
            #expect(QuestionnaireSchedule.due(now: now, results: none, arthritis: status, calendar: calendar) == [.skinImpact, .jointCheck])
        }
    }

    @Test func arthritisRaisesSeverityWhenKnownOrJointSymptomsNoted() {
        #expect(ArthritisRules.isSuspected(status: .diagnosed, jointSymptomsNoted: false))
        #expect(ArthritisRules.isSuspected(status: .suspected, jointSymptomsNoted: false))
        #expect(!ArthritisRules.isSuspected(status: .no, jointSymptomsNoted: false))
        #expect(ArthritisRules.isSuspected(status: .unsure, jointSymptomsNoted: true))
        #expect(!ArthritisRules.isSuspected(status: nil, jointSymptomsNoted: false))
    }

    @Test func takenTodayIsNotDue() {
        let results: [(kind: QuestionnaireKind, date: Date)] = [(.skinImpact, now), (.jointCheck, now)]
        #expect(QuestionnaireSchedule.due(now: now, results: results, calendar: calendar).isEmpty)
    }

    @Test func retiredResultsDontCountAndAreNeverDue() {
        let results: [(kind: QuestionnaireKind, date: Date)] = [(.dlqi, now), (.pest, now)]
        #expect(QuestionnaireSchedule.due(now: now, results: results, calendar: calendar) == [.skinImpact, .jointCheck])
    }

    @Test func skinImpactIsDueAfterThirtyDays() {
        #expect(!QuestionnaireSchedule.isDue(.skinImpact, lastTaken: daysAgo(29), now: now, calendar: calendar))
        #expect(QuestionnaireSchedule.isDue(.skinImpact, lastTaken: daysAgo(30), now: now, calendar: calendar))
    }

    @Test func jointCheckIsDueAfterThreeMonths() {
        #expect(!QuestionnaireSchedule.isDue(.jointCheck, lastTaken: daysAgo(60), now: now, calendar: calendar))
        #expect(QuestionnaireSchedule.isDue(.jointCheck, lastTaken: daysAgo(91), now: now, calendar: calendar))
    }

    @Test func latestResultCounts() {
        let results: [(kind: QuestionnaireKind, date: Date)] = [(.skinImpact, daysAgo(5)), (.skinImpact, daysAgo(80)), (.jointCheck, daysAgo(100))]
        #expect(QuestionnaireSchedule.due(now: now, results: results, calendar: calendar) == [.jointCheck])
    }
}
