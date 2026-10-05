import Foundation

/// One local notification to schedule. Texts are neutral: no diagnosis, no medicine names.
struct PlannedReminder: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case checkIn
        case dose
    }

    /// Stable id; every id starts with `ReminderPlan.idPrefix`.
    let id: String
    let kind: Kind
    /// Calendar match; for a repeating reminder only hour and minute are set.
    let dateComponents: DateComponents
    let repeats: Bool
    let title: String
    let body: String
}

/// Treatment schedule plus its marks, as input for reminders.
struct ReminderSchedule: Hashable, Sendable {
    let schedule: DoseSchedule
    let logs: [LoggedDose]
}

extension Treatment {
    var reminderSchedule: ReminderSchedule {
        ReminderSchedule(schedule: doseSchedule, logs: doses.map(\.logged))
    }
}

/// Which reminders should be pending right now (spec §6, migration plan step 36).
enum ReminderPlan {
    static let idPrefix = "myskin."
    static let title = "MySkin"
    static let checkInBody = "Time for your diary check-in."
    static let doseBody = "Time for your treatment."

    /// Dose reminders are planned this many days ahead and refreshed whenever the app is opened.
    static let daysAhead = 7
    /// iOS keeps at most 64 pending notifications per app; stay below it.
    static let limit = 60

    static func reminders(
        now: Date,
        checkInEnabled: Bool,
        checkInMinutes: Int,
        dosesEnabled: Bool,
        schedules: [ReminderSchedule],
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        var result: [PlannedReminder] = []

        if checkInEnabled {
            let minutes = min(max(checkInMinutes, 0), 24 * 60 - 1)
            result.append(PlannedReminder(
                id: "\(idPrefix)checkin.daily",
                kind: .checkIn,
                dateComponents: DateComponents(hour: minutes / 60, minute: minutes % 60),
                repeats: true,
                title: title,
                body: checkInBody
            ))
        }

        if dosesEnabled {
            // Open doses still ahead of now; several treatments at the same moment share one reminder.
            var slots = Set<Date>()
            let today = calendar.startOfDay(for: now)
            for offset in 0..<daysAhead {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                for item in schedules {
                    for dose in DoseScheduler.doses(on: day, schedule: item.schedule, logs: item.logs, calendar: calendar)
                    where dose.isOpen && dose.scheduledAt > now {
                        slots.insert(dose.scheduledAt)
                    }
                }
            }
            let room = limit - result.count
            for slot in slots.sorted().prefix(room) {
                result.append(PlannedReminder(
                    id: "\(idPrefix)dose.\(Int(slot.timeIntervalSince1970))",
                    kind: .dose,
                    dateComponents: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: slot),
                    repeats: false,
                    title: title,
                    body: doseBody
                ))
            }
        }
        return result
    }
}
