import Foundation
import Observation
import SwiftData

/// Onboarding answers kept in memory until the last step, then saved as `Profile`,
/// the baseline body map (`ZoneAssessment`) and the current treatments (`Treatment`).
@Observable
final class OnboardingDraft {
    var hasAcceptedDisclaimer = false
    var psoriasisTypes: Set<PsoriasisType> = []
    var onsetYear: Int?
    /// Self-rated skin, 0 (clear) … 1 (very bad).
    var skinNow = 0.35
    var goals: Set<Goal> = []
    /// Quick body map: zone id → level 1…3. Missing means clear.
    var zoneLevels: [String: Int] = [:]
    var treatments: [TreatmentDraft] = []
    var hasNoTreatment = false

    /// Share of a zone's reference area assumed for each quick level.
    static let coverage: [Int: Double] = [1: 0.25, 2: 0.5, 3: 0.8]

    /// Years offered for «when did it start», newest first.
    static func onsetYears(now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let current = calendar.component(.year, from: now)
        return Array(stride(from: current, through: current - 80, by: -1))
    }

    // MARK: Body map

    func cycleLevel(for zoneID: String) {
        let next = ((zoneLevels[zoneID] ?? 0) + 1) % 4
        zoneLevels[zoneID] = next == 0 ? nil : next
    }

    /// Quick level → full zone score: area from `coverage`, every sign equal to the level,
    /// so the map colors match (`SeverityCalculator.level`).
    static func score(zoneID: String, level: Int) -> ZoneScore? {
        guard let zone = BodyZone.zone(id: zoneID), let share = coverage[level] else { return nil }
        let palms = (zone.area * share * 10).rounded() / 10
        return ZoneScore(zoneID: zoneID, palms: max(palms, 0.1), erythema: level, induration: level, scale: level)
    }

    var zoneScores: [ZoneScore] {
        BodyZone.all.compactMap { zone in zoneLevels[zone.id].flatMap { Self.score(zoneID: zone.id, level: $0) } }
    }

    var snapshot: SeveritySnapshot { SeverityCalculator.snapshot(for: zoneScores) }

    // MARK: Treatments

    func add(_ medication: Medication) {
        guard !treatments.contains(where: { $0.catalogID == medication.id }) else { return }
        treatments.append(TreatmentDraft(medication: medication))
        hasNoTreatment = false
    }

    func addCustom(_ name: String) {
        let draft = TreatmentDraft(customName: name)
        guard draft.isValid, !treatments.contains(where: { $0.trimmedName.caseInsensitiveCompare(draft.trimmedName) == .orderedSame }) else { return }
        treatments.append(draft)
        hasNoTreatment = false
    }

    func removeTreatment(at index: Int) {
        guard treatments.indices.contains(index) else { return }
        treatments.remove(at: index)
    }

    /// Psoriasis types in a stable order for display and storage.
    var orderedTypes: [PsoriasisType] { PsoriasisType.allCases.filter(psoriasisTypes.contains) }

    // MARK: Save

    /// Writes everything in one save. An existing profile is updated, not duplicated.
    func save(in context: ModelContext, date: Date = .now) throws {
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let profile = profiles.first ?? Profile(createdAt: date)
        if profiles.isEmpty { context.insert(profile) }
        profile.psoriasisTypes = orderedTypes
        profile.onsetYear = onsetYear
        profile.goals = Goal.allCases.filter(goals.contains)
        profile.baselineSelfRating = skinNow

        for score in zoneScores {
            try ZoneAssessmentDraft(score).save(zoneID: score.zoneID, day: date, in: context)
        }
        for draft in treatments {
            var dated = draft
            dated.startDate = date
            context.insert(dated.makeTreatment())
        }
        try context.save()
    }
}
