#if DEBUG
import Foundation
import SwiftData

/// Sample data for previews and the design canvas. Debug builds only — never used by the real app.
enum PreviewData {
    /// Shared in-memory container filled with sample records.
    static let container: ModelContainer = {
        do {
            let container = try AppModelContainer.makeInMemory()
            populate(container.mainContext)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()

    /// Same sample data, but today's check-in has high itch and new spots, so Today is in Flare mode.
    static let flareContainer: ModelContainer = {
        do {
            let container = try AppModelContainer.makeInMemory()
            populate(container.mainContext, flare: true)
            return container
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }()

    /// Settings for previews, in their own defaults domain so previews never touch the app's settings.
    static let settings: AppSettings = {
        let suite = "MySkin.preview"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.hasCompletedOnboarding = true
        return settings
    }()

    /// Empty in-memory container, for empty states.
    static func emptyContainer() -> ModelContainer {
        do {
            return try AppModelContainer.makeInMemory()
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }

    static func populate(_ context: ModelContext, today: Date = .now, flare: Bool = false, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: today)
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: today) ?? today }

        context.insert(Profile(
            psoriasisTypes: [.plaque, .scalp],
            onsetYear: 2016,
            goals: [.triggers, .treatment],
            baselineSelfRating: 0.55,
            createdAt: daysAgo(90)
        ))

        // Two weeks of check-ins, itch easing off.
        let itch = [6, 7, 6, 5, 6, 4, 5, 4, 3, 4, 3, 2, 3, flare ? 8 : 3]
        for (offset, value) in itch.enumerated() {
            let ago = itch.count - 1 - offset
            context.insert(DailyCheckIn(
                day: daysAgo(ago),
                itch: value,
                pain: max(value - 3, 0),
                sleep: 10 - value,
                mood: value > 5 ? 2 : 4,
                triggers: ago == 12 ? [.stress] : ago == 10 ? [.alcohol, .stress] : [],
                newSpots: ago == 12 || (flare && ago == 0),
                calendar: calendar
            ))
        }

        // Body map: a week ago and today.
        let zones: [(String, Double, Int)] = [
            ("back.elbow.left", 0.4, 3),
            ("back.elbow.right", 0.4, 3),
            ("front.knee.left", 0.5, 2),
            ("front.knee.right", 0.5, 2),
            ("back.torso.lower", 1.5, 1),
            ("quick.scalp", 0.5, 2),
        ]
        for (zoneID, palms, level) in zones {
            context.insert(ZoneAssessment(day: daysAgo(7), zoneID: zoneID, palms: palms + 0.5, erythema: min(level + 1, 4), induration: level, scale: level, calendar: calendar))
            context.insert(ZoneAssessment(day: today, zoneID: zoneID, palms: palms, erythema: level, induration: max(level - 1, 0), scale: level, calendar: calendar))
        }

        // Treatment plan.
        let ointment = SchemaV1.Treatment(
            name: "Clobetasol 0.05% ointment", catalogID: "clobetasol", kind: .ointment, steroidClass: .class1,
            scheduleKind: .timesPerDay, timesPerDay: 2, doseMinutes: [8 * 60, 21 * 60], fingertipUnits: 1,
            zoneIDs: ["back.elbow.left", "back.elbow.right", "front.knee.left", "front.knee.right"],
            startDate: daysAgo(20)
        )
        let shampoo = SchemaV1.Treatment(
            name: "Coal tar shampoo", kind: .shampoo,
            scheduleKind: .everyNDays, interval: 2, doseMinutes: [20 * 60],
            zoneIDs: ["quick.scalp"], startDate: daysAgo(46)
        )
        let biologic = SchemaV1.Treatment(
            name: "Adalimumab 40 mg", catalogID: "adalimumab", kind: .biologic,
            scheduleKind: .everyNWeeks, interval: 2, doseMinutes: [9 * 60], startDate: daysAgo(30)
        )
        let emollient = SchemaV1.Treatment(
            name: "Rich emollient cream", kind: .cream, scheduleKind: .asNeeded, startDate: daysAgo(120)
        )
        [ointment, shampoo, biologic, emollient].forEach(context.insert)

        // Logs close their planned slots (`scheduledAt`), like marks made on Today.
        func at(_ ago: Int, _ minutes: Int) -> Date { daysAgo(ago).addingTimeInterval(TimeInterval(minutes * 60)) }
        for ago in 1...6 {
            context.insert(DoseLog(treatment: ointment, scheduledAt: at(ago, 8 * 60), timestamp: at(ago, 8 * 60), status: .done, fingertipUnits: 1))
            context.insert(DoseLog(treatment: ointment, scheduledAt: at(ago, 21 * 60), timestamp: at(ago, 21 * 60), status: ago == 3 ? .skipped : .done))
        }
        context.insert(DoseLog(treatment: biologic, scheduledAt: at(30, 9 * 60), timestamp: at(30, 9 * 60), status: .done, injectionSite: .abdomenRight))
        context.insert(DoseLog(treatment: biologic, scheduledAt: at(16, 9 * 60), timestamp: at(16, 9 * 60), status: .done, injectionSite: .thighLeft))
        context.insert(DoseLog(treatment: biologic, scheduledAt: at(2, 9 * 60), timestamp: at(2, 9 * 60), status: .done, injectionSite: .thighRight))

        // Questionnaires.
        context.insert(QuestionnaireResult(kind: .dlqi, date: daysAgo(60), answers: [2, 2, 1, 1, 2, 1, 1, 1, 1, 0], score: 12))
        context.insert(QuestionnaireResult(kind: .dlqi, date: daysAgo(28), answers: [1, 1, 1, 0, 1, 1, 0, 1, 0, 0], score: 6))
        context.insert(QuestionnaireResult(kind: .pest, date: daysAgo(60), answers: [0, 1, 0, 0, 1], score: 2))

        // Photos need image files, so the sample set has none; photo previews show the empty state.
    }
}
#endif
