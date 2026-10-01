import Foundation

// MARK: - Input

/// Value copy of a treatment's schedule fields.
struct DoseSchedule: Hashable, Sendable {
    var kind: ScheduleKind
    var timesPerDay: Int = 1
    /// N for `everyNDays` / `everyNWeeks`.
    var interval: Int = 1
    /// For `weekly`: 1 = Sunday … 7 = Saturday. Nil uses the start date's weekday.
    var weekday: Int? = nil
    /// Minutes after midnight. Empty uses default times.
    var doseMinutes: [Int] = []
    /// Interval schedules count from this day.
    var startDate: Date
    /// No doses at or after this moment.
    var endDate: Date? = nil
}

extension SchemaV1.Treatment {
    var doseSchedule: DoseSchedule {
        DoseSchedule(
            kind: scheduleKind, timesPerDay: timesPerDay, interval: interval, weekday: weekday,
            doseMinutes: doseMinutes, startDate: startDate, endDate: endDate
        )
    }
}

/// Value copy of a `DoseLog` entry.
struct LoggedDose: Hashable, Sendable {
    let scheduledAt: Date?
    let status: DoseStatus
}

extension DoseLog {
    var logged: LoggedDose { LoggedDose(scheduledAt: scheduledAt, status: status) }
}

// MARK: - Output

struct ScheduledDose: Hashable, Sendable {
    let scheduledAt: Date
    /// Nil while the dose is not marked as done or skipped.
    let status: DoseStatus?

    var isOpen: Bool { status == nil }
}

// MARK: - Scheduler

/// Builds planned doses from a treatment schedule (spec §2.4).
/// Interval schedules stay anchored to the start date, even if a dose was taken late.
enum DoseScheduler {
    /// Default dose time when none is set: 08:00.
    static let defaultMinute = 8 * 60
    /// Several daily doses are spread from 08:00 to 20:00.
    static let lastDefaultMinute = 20 * 60
    /// How far `nextDose` looks ahead.
    static let searchDays = 400

    /// Default times for N doses a day: 1 → 08:00, 2 → 08:00 / 20:00, 3 → 08:00 / 14:00 / 20:00.
    static func defaultMinutes(count: Int) -> [Int] {
        guard count > 1 else { return count == 1 ? [defaultMinute] : [] }
        let step = Double(lastDefaultMinute - defaultMinute) / Double(count - 1)
        return (0..<count).map { defaultMinute + Int((Double($0) * step).rounded()) }
    }

    /// Dose times on a dose day, minutes after midnight, sorted.
    static func minutes(for schedule: DoseSchedule) -> [Int] {
        switch schedule.kind {
        case .timesPerDay:
            schedule.doseMinutes.count == schedule.timesPerDay
                ? schedule.doseMinutes.sorted()
                : defaultMinutes(count: schedule.timesPerDay)
        case .weekly, .everyNDays, .everyNWeeks:
            [schedule.doseMinutes.min() ?? defaultMinute]
        case .asNeeded:
            []
        }
    }

    static func isDoseDay(_ date: Date, schedule: DoseSchedule, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: schedule.startDate)
        guard day >= start else { return false }
        if let end = schedule.endDate, day > calendar.startOfDay(for: end) { return false }

        let daysSinceStart = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        switch schedule.kind {
        case .timesPerDay:
            return true
        case .weekly:
            let weekday = schedule.weekday ?? calendar.component(.weekday, from: start)
            return calendar.component(.weekday, from: day) == weekday
        case .everyNDays:
            return daysSinceStart % max(schedule.interval, 1) == 0
        case .everyNWeeks:
            return daysSinceStart % (7 * max(schedule.interval, 1)) == 0
        case .asNeeded:
            return false
        }
    }

    /// Planned doses on one day with their marks. A log closes the slot it was scheduled for.
    static func doses(
        on date: Date,
        schedule: DoseSchedule,
        logs: [LoggedDose] = [],
        calendar: Calendar = .current
    ) -> [ScheduledDose] {
        guard isDoseDay(date, schedule: schedule, calendar: calendar) else { return [] }
        let day = calendar.startOfDay(for: date)

        var statusBySlot: [Date: DoseStatus] = [:]
        for log in logs {
            if let slot = log.scheduledAt { statusBySlot[slot] = log.status }
        }

        return minutes(for: schedule).compactMap { minute in
            let clamped = min(max(minute, 0), 24 * 60 - 1)
            guard let slot = calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: day) else { return nil }
            if let end = schedule.endDate, slot >= end { return nil }
            return ScheduledDose(scheduledAt: slot, status: statusBySlot[slot])
        }
    }

    /// First open dose from the start of the given day, e.g. the next injection date.
    /// Today's unmarked doses count, even if their time has passed.
    static func nextDose(
        onOrAfter date: Date,
        schedule: DoseSchedule,
        logs: [LoggedDose] = [],
        calendar: Calendar = .current
    ) -> Date? {
        guard schedule.kind != .asNeeded else { return nil }
        let first = calendar.startOfDay(for: date)
        for offset in 0..<searchDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            if let end = schedule.endDate, day > end { return nil }
            if let open = doses(on: day, schedule: schedule, logs: logs, calendar: calendar).first(where: \.isOpen) {
                return open.scheduledAt
            }
        }
        return nil
    }
}

// MARK: - Description

extension DoseScheduler {
    /// Short schedule text for lists, e.g. «Twice a day», «Every 2 weeks», «Weekly · Monday».
    static func summary(for schedule: DoseSchedule, calendar: Calendar = .current) -> String {
        switch schedule.kind {
        case .timesPerDay:
            switch schedule.timesPerDay {
            case ...1: return "Once a day"
            case 2: return "Twice a day"
            default: return "\(schedule.timesPerDay) times a day"
            }
        case .weekly:
            let weekday = schedule.weekday ?? calendar.component(.weekday, from: schedule.startDate)
            let names = calendar.standaloneWeekdaySymbols
            let name = names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
            return name.isEmpty ? "Once a week" : "Weekly · \(name)"
        case .everyNDays:
            return schedule.interval <= 1 ? "Every day" : "Every \(schedule.interval) days"
        case .everyNWeeks:
            return schedule.interval <= 1 ? "Every week" : "Every \(schedule.interval) weeks"
        case .asNeeded:
            return "As needed"
        }
    }
}
