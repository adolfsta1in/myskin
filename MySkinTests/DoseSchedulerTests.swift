import Foundation
import Testing
@testable import MyApp

struct DoseSchedulerTests {
    /// Fixed calendar so the tests do not depend on the machine's time zone.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// Thursday, 1 October 2026, at the given time.
    private func date(day: Int = 1, month: Int = 10, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .now
    }

    private var start: Date { date(hour: 9) }

    // MARK: - Times a day

    @Test func twiceADayUsesDefaultTimes() {
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 2, startDate: start)
        let doses = DoseScheduler.doses(on: date(day: 3), schedule: schedule, calendar: calendar)
        let times = doses.map { $0.scheduledAt }
        #expect(times == [date(day: 3, hour: 8), date(day: 3, hour: 20)])
        #expect(doses.allSatisfy { $0.isOpen })
    }

    @Test func defaultTimesAreSpreadThroughTheDay() {
        #expect(DoseScheduler.defaultMinutes(count: 0) == [])
        #expect(DoseScheduler.defaultMinutes(count: 1) == [480])
        #expect(DoseScheduler.defaultMinutes(count: 3) == [480, 840, 1200])
    }

    @Test func customTimesAreUsedWhenTheyMatchTheCount() {
        let custom = DoseSchedule(kind: .timesPerDay, timesPerDay: 2, doseMinutes: [21 * 60 + 30, 7 * 60 + 15], startDate: start)
        #expect(DoseScheduler.doses(on: date(day: 2), schedule: custom, calendar: calendar).map(\.scheduledAt)
            == [date(day: 2, hour: 7, minute: 15), date(day: 2, hour: 21, minute: 30)])

        let mismatch = DoseSchedule(kind: .timesPerDay, timesPerDay: 2, doseMinutes: [600], startDate: start)
        #expect(DoseScheduler.doses(on: date(day: 2), schedule: mismatch, calendar: calendar).count == 2)
    }

    @Test func markedDosesAreClosed() {
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 2, startDate: start)
        let logs = [
            LoggedDose(scheduledAt: date(day: 2, hour: 8), status: .done),
            // Ad-hoc entry without a slot does not close anything.
            LoggedDose(scheduledAt: nil, status: .done),
        ]
        let doses = DoseScheduler.doses(on: date(day: 2), schedule: schedule, logs: logs, calendar: calendar)
        #expect(doses.map(\.status) == [.done, nil])
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 2, hour: 12), schedule: schedule, logs: logs, calendar: calendar) == date(day: 2, hour: 20))
    }

    @Test func skippedDoseCountsAsMarked() {
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 1, startDate: start)
        let logs = [LoggedDose(scheduledAt: date(day: 2, hour: 8), status: .skipped)]
        #expect(DoseScheduler.doses(on: date(day: 2), schedule: schedule, logs: logs, calendar: calendar).map(\.status) == [.skipped])
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 2), schedule: schedule, logs: logs, calendar: calendar) == date(day: 3, hour: 8))
    }

    // MARK: - Weekly

    @Test func weeklyDefaultsToStartWeekday() {
        let schedule = DoseSchedule(kind: .weekly, startDate: start)
        #expect(DoseScheduler.doses(on: date(day: 7), schedule: schedule, calendar: calendar).isEmpty)
        #expect(DoseScheduler.doses(on: date(day: 8), schedule: schedule, calendar: calendar).map(\.scheduledAt) == [date(day: 8, hour: 8)])
    }

    @Test func weeklyOnChosenWeekday() {
        // 2 = Monday; 5 October 2026 is a Monday.
        let schedule = DoseSchedule(kind: .weekly, weekday: 2, doseMinutes: [19 * 60], startDate: start)
        #expect(DoseScheduler.nextDose(onOrAfter: start, schedule: schedule, calendar: calendar) == date(day: 5, hour: 19))
    }

    // MARK: - Every N weeks / days

    @Test func everyTwoWeeks() {
        let schedule = DoseSchedule(kind: .everyNWeeks, interval: 2, startDate: start)
        #expect(DoseScheduler.isDoseDay(date(day: 1), schedule: schedule, calendar: calendar))
        #expect(!DoseScheduler.isDoseDay(date(day: 8), schedule: schedule, calendar: calendar))
        #expect(DoseScheduler.isDoseDay(date(day: 15), schedule: schedule, calendar: calendar))
        #expect(DoseScheduler.isDoseDay(date(day: 29), schedule: schedule, calendar: calendar))
    }

    @Test func nextInjectionSkipsTheDoneOne() {
        let schedule = DoseSchedule(kind: .everyNWeeks, interval: 2, startDate: start)
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 1), schedule: schedule, calendar: calendar) == date(day: 1, hour: 8))

        let logs = [LoggedDose(scheduledAt: date(day: 1, hour: 8), status: .done)]
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 1), schedule: schedule, logs: logs, calendar: calendar) == date(day: 15, hour: 8))
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 2), schedule: schedule, calendar: calendar) == date(day: 15, hour: 8))
    }

    @Test func everyTwelveWeeksLooksFarAhead() {
        let schedule = DoseSchedule(kind: .everyNWeeks, interval: 12, startDate: start)
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 2), schedule: schedule, calendar: calendar) == date(day: 24, month: 12, hour: 8))
    }

    @Test func everyThreeDays() {
        let schedule = DoseSchedule(kind: .everyNDays, interval: 3, startDate: start)
        let days = (1...10).filter { DoseScheduler.isDoseDay(date(day: $0), schedule: schedule, calendar: calendar) }
        #expect(days == [1, 4, 7, 10])
    }

    // MARK: - Limits

    @Test func noDosesBeforeStart() {
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 2, startDate: start)
        #expect(DoseScheduler.doses(on: date(day: 30, month: 9), schedule: schedule, calendar: calendar).isEmpty)
    }

    @Test func noDosesAfterStop() {
        // Stopped at noon on 3 October: the evening dose and later days are gone.
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 2, startDate: start, endDate: date(day: 3, hour: 12))
        #expect(DoseScheduler.doses(on: date(day: 3), schedule: schedule, calendar: calendar).map(\.scheduledAt) == [date(day: 3, hour: 8)])
        #expect(DoseScheduler.doses(on: date(day: 4), schedule: schedule, calendar: calendar).isEmpty)
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 4), schedule: schedule, calendar: calendar) == nil)
    }

    @Test func asNeededHasNoPlannedDoses() {
        let schedule = DoseSchedule(kind: .asNeeded, startDate: start)
        #expect(DoseScheduler.doses(on: date(day: 2), schedule: schedule, calendar: calendar).isEmpty)
        #expect(DoseScheduler.nextDose(onOrAfter: date(day: 2), schedule: schedule, calendar: calendar) == nil)
    }
}
