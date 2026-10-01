import Foundation
import SwiftData

/// One planned dose of an active treatment on a given day.
struct DoseRow: Identifiable {
    let treatment: Treatment
    let scheduledAt: Date
    let status: DoseStatus?

    var id: String { "\(treatment.persistentModelID.hashValue)-\(scheduledAt.timeIntervalSinceReferenceDate)" }
    var isDone: Bool { status != nil }
}

enum DoseRows {
    /// Planned doses of all active treatments on `day`, by time then name. Uses `DoseScheduler`.
    static func rows(for treatments: [Treatment], on day: Date, calendar: Calendar = .current) -> [DoseRow] {
        treatments
            .filter(\.isActive)
            .flatMap { treatment in
                DoseScheduler.doses(on: day, schedule: treatment.doseSchedule, logs: treatment.doses.map(\.logged), calendar: calendar)
                    .map { DoseRow(treatment: treatment, scheduledAt: $0.scheduledAt, status: $0.status) }
            }
            .sorted { ($0.scheduledAt, $0.treatment.name) < ($1.scheduledAt, $1.treatment.name) }
    }

    /// Marks an open dose as done, or removes the mark from a closed one. Saves the context.
    static func toggle(_ row: DoseRow, injectionSite: InjectionSite? = nil, in context: ModelContext) throws {
        let marked = row.treatment.doses.filter { $0.scheduledAt == row.scheduledAt }
        if marked.isEmpty {
            context.insert(DoseLog(
                treatment: row.treatment,
                scheduledAt: row.scheduledAt,
                status: .done,
                injectionSite: injectionSite,
                fingertipUnits: row.treatment.fingertipUnits
            ))
        } else {
            marked.forEach(context.delete)
        }
        try context.save()
    }
}
