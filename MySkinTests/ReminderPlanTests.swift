import Foundation
import Testing
@testable import MyApp

struct ReminderPlanTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 1 October 2026 at the given time.
    private func date(day: Int = 1, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .now
    }

    private func plan(
        now: Date,
        checkIn: Bool = false,
        minutes: Int = 20 * 60,
        doses: Bool = true,
        _ schedules: [ReminderSchedule] = []
    ) -> [PlannedReminder] {
        ReminderPlan.reminders(now: now, checkInEnabled: checkIn, checkInMinutes: minutes, dosesEnabled: doses, schedules: schedules, calendar: calendar)
    }

    private var twiceADay: ReminderSchedule {
        ReminderSchedule(schedule: DoseSchedule(kind: .timesPerDay, timesPerDay: 2, startDate: date(day: 1, hour: 0)), logs: [])
    }

    @Test func dailyCheckInRepeatsAtChosenTime() throws {
        let reminders = plan(now: date(hour: 9), checkIn: true, minutes: 21 * 60 + 30, doses: false)
        let checkIn = try #require(reminders.first)
        #expect(reminders.count == 1)
        #expect(checkIn.kind == .checkIn)
        #expect(checkIn.repeats)
        #expect(checkIn.dateComponents.hour == 21 && checkIn.dateComponents.minute == 30)
        #expect(checkIn.body == "Time for your diary check-in.")
    }

    @Test func nothingWhenSwitchedOff() {
        #expect(plan(now: date(hour: 9), checkIn: false, doses: false, [twiceADay]).isEmpty)
    }

    @Test func dosesAheadOnlyForSevenDays() {
        // At 09:00 today's 08:00 dose is past: 20:00 today + 2 × 6 days.
        let doses = plan(now: date(hour: 9), [twiceADay]).filter { $0.kind == .dose }
        #expect(doses.count == 13)
        #expect(doses.first?.dateComponents.hour == 20)
        #expect(doses.allSatisfy { !$0.repeats })
    }

    @Test func markedDoseIsNotReminded() {
        let marked = ReminderSchedule(
            schedule: twiceADay.schedule,
            logs: [LoggedDose(scheduledAt: date(hour: 20), status: .done)]
        )
        let doses = plan(now: date(hour: 9), [marked]).filter { $0.kind == .dose }
        #expect(doses.count == 12)
        #expect(doses.first?.dateComponents.day == 2)
    }

    @Test func sameTimeTreatmentsShareOneReminder() {
        let doses = plan(now: date(hour: 9), [twiceADay, twiceADay]).filter { $0.kind == .dose }
        #expect(doses.count == 13)
    }

    @Test func textsNeverNameMedicines() {
        let all = plan(now: date(hour: 9), checkIn: true, [twiceADay])
        #expect(Set(all.map(\.body)) == [ReminderPlan.checkInBody, ReminderPlan.doseBody])
        #expect(all.allSatisfy { $0.title == "MySkin" && $0.id.hasPrefix(ReminderPlan.idPrefix) })
    }

    @Test func staysUnderSystemLimit() {
        let often = ReminderSchedule(schedule: DoseSchedule(kind: .timesPerDay, timesPerDay: 6, startDate: date(day: 1, hour: 0)), logs: [])
        let other = ReminderSchedule(schedule: DoseSchedule(kind: .timesPerDay, timesPerDay: 5, doseMinutes: [7 * 60, 11 * 60, 15 * 60, 19 * 60, 23 * 60], startDate: date(day: 1, hour: 0)), logs: [])
        #expect(plan(now: date(hour: 0), checkIn: true, [often, other]).count == ReminderPlan.limit)
    }
}
