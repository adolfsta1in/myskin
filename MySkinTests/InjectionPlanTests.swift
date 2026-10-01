import Foundation
import Testing
@testable import MyApp

struct InjectionPlanTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    /// Thursday, 1 October 2026.
    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .now
    }

    @Test func nothingLoggedSuggestsFirstSite() {
        #expect(InjectionPlan.lastSite([]) == nil)
        #expect(InjectionPlan.suggestedSite(after: nil) == .abdomenLeft)
    }

    @Test func rotationFollowsLastSite() {
        let records = [
            InjectionRecord(date: date(day: 1), site: .thighLeft),
            InjectionRecord(date: date(day: 15), site: .abdomenLeft),
            InjectionRecord(date: date(day: 20), site: nil),
        ]
        #expect(InjectionPlan.lastSite(records) == .abdomenLeft)
        #expect(InjectionPlan.suggestedSite(after: .abdomenLeft) == .abdomenRight)
        #expect(InjectionPlan.suggestedSite(after: .thighRight) == .abdomenLeft)
    }

    @Test func countdownAfterMarkedInjection() {
        // Every 2 weeks from 1 October at 09:00; today's dose is marked.
        let schedule = DoseSchedule(kind: .everyNWeeks, interval: 2, doseMinutes: [9 * 60], startDate: date(day: 1, hour: 9))
        let today = date(day: 1)
        #expect(InjectionPlan.daysUntilNextDose(from: today, schedule: schedule, logs: [], calendar: calendar) == 0)
        let marked = [LoggedDose(scheduledAt: date(day: 1, hour: 9), status: .done)]
        #expect(InjectionPlan.daysUntilNextDose(from: today, schedule: schedule, logs: marked, calendar: calendar) == 14)
        #expect(InjectionPlan.daysUntilNextDose(from: date(day: 10), schedule: schedule, logs: marked, calendar: calendar) == 5)
    }

    @Test func countdownText() {
        #expect(InjectionPlan.countdownText(days: 0, from: date(day: 1), calendar: calendar) == "Next injection today")
        #expect(InjectionPlan.countdownText(days: 1, from: date(day: 1), calendar: calendar) == "Next injection tomorrow")
        #expect(InjectionPlan.countdownText(days: 5, from: date(day: 10), calendar: calendar).hasPrefix("Next injection in 5 days · "))
    }
}
