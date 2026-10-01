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
}
