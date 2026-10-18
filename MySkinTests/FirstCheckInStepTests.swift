import Foundation
import SwiftData
import Testing
@testable import MySkin

struct FirstCheckInStepTests {
    @Test func checkInComesRightAfterTreatments() {
        let steps = OnboardingStep.allCases
        #expect(steps.firstIndex(of: .firstCheckIn) == (steps.firstIndex(of: .treatments) ?? 0) + 1)
        #expect(steps.last == .commitment)
    }

    /// The promise is the last thing before the paywall, right after the plan.
    @Test func commitmentComesRightAfterThePlan() {
        let steps = OnboardingStep.allCases
        #expect(steps.firstIndex(of: .commitment) == (steps.firstIndex(of: .plan) ?? 0) + 1)
        #expect(OnboardingStep.commitment.isOptional)
    }

    @Test func firstCheckInIsSavedAsToday() throws {
        let context = ModelContext(try AppModelContainer.makeInMemory())
        let draft = OnboardingDraft()
        draft.firstCheckIn.itch = 6
        draft.firstCheckIn.triggers = [.stress]
        draft.hasFirstCheckIn = true
        try draft.save(in: context)

        let checkIns = try context.fetch(FetchDescriptor<DailyCheckIn>())
        #expect(checkIns.count == 1)
        #expect(checkIns.first?.itch == 6)
        #expect(checkIns.first?.triggers == [.stress])
        #expect(checkIns.first?.day == Calendar.current.startOfDay(for: .now))
    }

    @Test func skippedCheckInSavesNothing() throws {
        let context = ModelContext(try AppModelContainer.makeInMemory())
        let draft = OnboardingDraft()
        draft.firstCheckIn.itch = 6
        try draft.save(in: context)
        #expect(try context.fetch(FetchDescriptor<DailyCheckIn>()).isEmpty)
    }
}
