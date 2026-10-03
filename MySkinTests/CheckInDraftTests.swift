import Foundation
import SwiftData
import Testing
@testable import MyApp

struct CheckInDraftTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    @Test func newDraftLeavesOptionalScalesUnset() {
        let checkIn = CheckInDraft().makeCheckIn(day: .now)
        #expect(checkIn.itch == 0)
        #expect(checkIn.pain == nil)
        #expect(checkIn.sleep == nil)
        #expect(checkIn.mood == nil)
    }

    @Test func saveThenReloadKeepsValues() throws {
        let context = try makeContext()
        var draft = CheckInDraft()
        draft.itch = 6
        draft.pain = 3
        draft.mood = 2
        draft.toggle(.stress)
        draft.toggle(.alcohol)
        draft.addCustomTag("  Hot shower ")
        draft.newSpots = true
        draft.note = " Itchy after gym \n"
        context.insert(draft.makeCheckIn(day: .now))
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<DailyCheckIn>()).first)
        // Triggers are stored in `Trigger.allCases` order, the note trimmed.
        #expect(stored.triggerIDs == ["stress", "alcohol"])
        #expect(stored.customTags == ["Hot shower"])
        #expect(stored.note == "Itchy after gym")

        let reloaded = CheckInDraft(stored)
        #expect(reloaded.itch == 6)
        #expect(reloaded.pain == 3)
        #expect(reloaded.sleep == nil)
        #expect(reloaded.mood == 2)
        #expect(reloaded.triggers == [.stress, .alcohol])
        #expect(reloaded.newSpots)
    }

    @Test func updatingKeepsOneRecordPerDay() throws {
        let context = try makeContext()
        var draft = CheckInDraft()
        draft.itch = 4
        context.insert(draft.makeCheckIn(day: .now))
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<DailyCheckIn>()).first)
        draft = CheckInDraft(stored)
        draft.itch = 8
        draft.toggle(.coldDry)
        draft.apply(to: stored)
        try context.save()

        let all = try context.fetch(FetchDescriptor<DailyCheckIn>())
        #expect(all.count == 1)
        #expect(all.first?.itch == 8)
        #expect(all.first?.triggers == [.coldDry])
    }

    @Test func customTagsIgnoreEmptyAndDuplicates() {
        var draft = CheckInDraft()
        draft.addCustomTag("   ")
        draft.addCustomTag("Gym", known: ["gym"])
        draft.addCustomTag("GYM")
        #expect(draft.customTags == ["gym"])

        draft.toggleCustomTag("gym")
        #expect(draft.customTags.isEmpty)
    }

    @Test func untouchedFoodIsSavedAsUnknown() {
        var draft = CheckInDraft()
        draft.itch = 3
        let checkIn = draft.makeCheckIn(day: .now)
        #expect(checkIn.foodIDs == nil)
        #expect(checkIn.customFoods.isEmpty)
        #expect(!CheckInDraft(checkIn).foodLogged)
    }

    @Test func noneOfTheseIsSavedAsEmpty() {
        var draft = CheckInDraft()
        draft.toggle(.dairy)
        draft.addCustomFood("Eggs")
        draft.markNoFood()
        #expect(draft.isNoFood)
        let checkIn = draft.makeCheckIn(day: .now)
        #expect(checkIn.foodIDs == [])
        #expect(checkIn.customFoods.isEmpty)
        #expect(CheckInDraft(checkIn).isNoFood)
    }

    @Test func foodsSaveAndReload() throws {
        let context = try makeContext()
        var draft = CheckInDraft()
        draft.toggle(.coffee)
        draft.toggle(.dairy)
        draft.toggle(.spicy)
        draft.toggle(.spicy)
        draft.addCustomFood(" Eggs ")
        #expect(!draft.isNoFood)
        context.insert(draft.makeCheckIn(day: .now))
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<DailyCheckIn>()).first)
        // Stored in `Food.allCases` order.
        #expect(stored.foodIDs == ["dairy", "coffee"])
        #expect(stored.foods == [.dairy, .coffee])
        #expect(stored.customFoods == ["Eggs"])

        var reloaded = CheckInDraft(stored)
        #expect(reloaded.foodLogged)
        #expect(reloaded.foods == [.dairy, .coffee])
        #expect(reloaded.customFoods == ["Eggs"])

        // Unticking everything still counts as logged.
        reloaded.toggle(.dairy)
        reloaded.toggle(.coffee)
        reloaded.toggleCustomFood("Eggs")
        reloaded.apply(to: stored)
        #expect(stored.foodIDs == [])
    }

    @Test func customFoodsIgnoreEmptyAndDuplicates() {
        var draft = CheckInDraft()
        draft.addCustomFood("  ")
        #expect(!draft.foodLogged)
        draft.addCustomFood("Eggs", known: ["eggs"])
        draft.addCustomFood("EGGS")
        #expect(draft.customFoods == ["eggs"])
        #expect(draft.foodLogged)
    }

    @Test func knownFoodsAreNewestFirstWithoutDuplicates() {
        let calendar = Calendar.current
        let old = DailyCheckIn(day: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now, itch: 1)
        old.customFoods = ["Eggs", "Pizza"]
        let recent = DailyCheckIn(day: .now, itch: 2)
        recent.customFoods = ["Nuts", "eggs"]
        #expect(CheckInDraft.knownFoods(from: [old, recent]) == ["Nuts", "eggs", "Pizza"])
    }

    @Test func knownTagsAreNewestFirstWithoutDuplicates() {
        let calendar = Calendar.current
        let old = DailyCheckIn(day: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now, itch: 1, customTags: ["Gym", "Exams"])
        let recent = DailyCheckIn(day: .now, itch: 2, customTags: ["Hot shower", "gym"])
        #expect(CheckInDraft.knownTags(from: [old, recent]) == ["Hot shower", "gym", "Exams"])
    }
}
