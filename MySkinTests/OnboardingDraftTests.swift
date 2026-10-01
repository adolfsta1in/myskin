import Foundation
import SwiftData
import Testing
@testable import MyApp

struct OnboardingDraftTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    @Test func savesProfile() throws {
        let context = try makeContext()
        let draft = OnboardingDraft()
        draft.psoriasisTypes = [.scalp, .plaque]
        draft.onsetYear = 2015
        draft.goals = [.doctor]
        draft.skinNow = 0.6
        try draft.save(in: context)

        let profiles = try context.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.psoriasisTypes == [.plaque, .scalp])
        #expect(profiles.first?.onsetYear == 2015)
        #expect(profiles.first?.goals == [.doctor])
        #expect(profiles.first?.baselineSelfRating == 0.6)
    }

    @Test func savingAgainUpdatesTheProfile() throws {
        let context = try makeContext()
        let draft = OnboardingDraft()
        try draft.save(in: context)
        draft.psoriasisTypes = [.nail]
        try draft.save(in: context)

        let profiles = try context.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.psoriasisTypes == [.nail])
    }

    @Test func onsetYearsStartThisYear() {
        let years = OnboardingDraft.onsetYears()
        #expect(years.first == Calendar.current.component(.year, from: .now))
        #expect(years.count == 81)
    }

    @Test func baselineMapAndTreatmentsBecomeData() throws {
        let context = try makeContext()
        let draft = OnboardingDraft()
        draft.cycleLevel(for: "front.torso.upper")
        draft.cycleLevel(for: "front.torso.upper")
        draft.cycleLevel(for: "quick.scalp")
        let clobetasol = try #require(MedicationCatalog.medication(id: "clobetasol.ointment"))
        draft.add(clobetasol)
        draft.add(clobetasol)
        draft.addCustom("Grandma's cream")
        draft.addCustom("grandma's cream")
        try draft.save(in: context)

        let assessments = try context.fetch(FetchDescriptor<ZoneAssessment>())
        #expect(Set(assessments.map(\.zoneID)) == ["front.torso.upper", "quick.scalp"])
        let chest = try #require(assessments.first { $0.zoneID == "front.torso.upper" })
        #expect(chest.palms == 4.5)
        #expect(SeverityCalculator.level(for: chest.score) == 2)

        let treatments = try context.fetch(FetchDescriptor<Treatment>(sortBy: [SortDescriptor(\.name)]))
        #expect(treatments.map(\.name) == ["Clobetasol propionate 0.05% ointment", "Grandma's cream"])
        #expect(treatments.first?.timesPerDay == 2)
        #expect(treatments.filter(\.isActive).count == 2)
    }

    @Test func cyclingReturnsToClear() {
        let draft = OnboardingDraft()
        for _ in 0..<4 { draft.cycleLevel(for: "quick.nails") }
        #expect(draft.zoneLevels.isEmpty)
        #expect(draft.snapshot.bsa == 0)
    }

    @Test func noTreatmentClearsWhenOneIsAdded() throws {
        let draft = OnboardingDraft()
        draft.hasNoTreatment = true
        draft.addCustom("Cream")
        #expect(!draft.hasNoTreatment)
        #expect(draft.treatments.count == 1)
    }
}
