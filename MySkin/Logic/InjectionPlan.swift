import Foundation

/// A marked injection: when and where.
struct InjectionRecord: Hashable, Sendable {
    let date: Date
    let site: InjectionSite?
}

extension DoseLog {
    var injectionRecord: InjectionRecord { InjectionRecord(date: scheduledAt ?? timestamp, site: injectionSite) }
}

/// Injection site rotation and the countdown to the next dose (biologics).
enum InjectionPlan {
    /// Site of the most recent injection that has one.
    static func lastSite(_ records: [InjectionRecord]) -> InjectionSite? {
        records.filter { $0.site != nil }.max { $0.date < $1.date }?.site
    }

    /// Next site in the fixed rotation order (`InjectionSite.allCases`); the first one if nothing was logged.
    static func suggestedSite(after last: InjectionSite?) -> InjectionSite {
        let all = InjectionSite.allCases
        guard let last, let index = all.firstIndex(of: last) else { return all[0] }
        return all[(index + 1) % all.count]
    }

    /// Whole days from `date` to the next open dose; 0 = today. Nil if none is planned.
    static func daysUntilNextDose(
        from date: Date,
        schedule: DoseSchedule,
        logs: [LoggedDose],
        calendar: Calendar = .current
    ) -> Int? {
        guard let next = DoseScheduler.nextDose(onOrAfter: date, schedule: schedule, logs: logs, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: next)).day
    }

    /// «Today», «Tomorrow» or «In 5 days · Friday».
    static func countdownText(days: Int, from date: Date, calendar: Calendar = .current) -> String {
        switch days {
        case 0: return "Next injection today"
        case 1: return "Next injection tomorrow"
        default:
            let day = calendar.date(byAdding: .day, value: days, to: date) ?? date
            return "Next injection in \(days) days · \(day.formatted(.dateTime.weekday(.wide)))"
        }
    }
}
