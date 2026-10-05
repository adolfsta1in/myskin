import Foundation
import SwiftData
import Testing
@testable import MySkin

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

    @Test func checkInSaveLeavesFoodUnknown() {
        var draft = CheckInDraft()
        draft.itch = 3
        let checkIn = draft.makeCheckIn(day: .now)
        #expect(checkIn.foodIDs == nil)
        #expect(checkIn.customFoods.isEmpty)
        #expect(!FoodDraft(checkIn).isLogged)
    }

    @Test func updatingCheckInKeepsLoggedFood() {
        let checkIn = CheckInDraft().makeCheckIn(day: .now)
        var food = FoodDraft()
        food.toggle(.dairy)
        food.apply(to: checkIn)
        var draft = CheckInDraft(checkIn)
        draft.itch = 6
        draft.apply(to: checkIn)
        #expect(checkIn.foods == [.dairy])
    }

    @Test func noneOfTheseIsSavedAsEmpty() {
        let checkIn = CheckInDraft().makeCheckIn(day: .now)
        var draft = FoodDraft()
        draft.toggle(.dairy)
        draft.addCustomFood("Eggs")
        draft.markNone()
        #expect(draft.isNone)
        draft.apply(to: checkIn)
        #expect(checkIn.foodIDs == [])
        #expect(checkIn.customFoods.isEmpty)
        #expect(FoodDraft(checkIn).isNone)
    }

    @Test func foodsSaveAndReload() throws {
        let context = try makeContext()
        let checkIn = CheckInDraft().makeCheckIn(day: .now)
        context.insert(checkIn)
        var draft = FoodDraft()
        draft.toggle(.coffee)
        draft.toggle(.dairy)
        draft.toggle(.spicy)
        draft.toggle(.spicy)
        draft.addCustomFood(" Eggs ")
        #expect(!draft.isNone)
        draft.apply(to: checkIn)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<DailyCheckIn>()).first)
        // Stored in `Food.allCases` order.
        #expect(stored.foodIDs == ["dairy", "coffee"])
        #expect(stored.foods == [.dairy, .coffee])
        #expect(stored.customFoods == ["Eggs"])

        var reloaded = FoodDraft(stored)
        #expect(reloaded.isLogged)
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
        var draft = FoodDraft()
        draft.addCustomFood("  ")
        #expect(!draft.isLogged)
        draft.addCustomFood("Eggs", known: ["eggs"])
        draft.addCustomFood("EGGS")
        #expect(draft.customFoods == ["eggs"])
        #expect(draft.isLogged)
    }

    @Test func knownFoodsAreNewestFirstWithoutDuplicates() {
        let calendar = Calendar.current
        let old = DailyCheckIn(day: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now, itch: 1)
        old.customFoods = ["Eggs", "Pizza"]
        let recent = DailyCheckIn(day: .now, itch: 2)
        recent.customFoods = ["Nuts", "eggs"]
        #expect(FoodDraft.knownFoods(from: [old, recent]) == ["Nuts", "eggs", "Pizza"])
    }

    @Test func foodHistorySkipsDaysWithoutFoodLog() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today) ?? today }
        let logged = DailyCheckIn(day: day(-3), itch: 1)
        logged.foodIDs = ["coffee"]
        let none = DailyCheckIn(day: day(-2), itch: 1)
        none.foodIDs = []
        let unlogged = DailyCheckIn(day: day(-1), itch: 1)
        let todays = DailyCheckIn(day: today, itch: 1)
        todays.foodIDs = ["dairy"]
        let history = FoodDraft.pickHistory(from: [logged, none, unlogged, todays], before: today)
        #expect(history == [[], [.food(.coffee)]])
    }

    @Test func pickHistoryIsNewestFirstAndExcludesToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let older = DailyCheckIn(day: calendar.date(byAdding: .day, value: -2, to: today) ?? today, itch: 1, triggers: [.stress])
        let yesterday = DailyCheckIn(day: calendar.date(byAdding: .day, value: -1, to: today) ?? today, itch: 1, triggers: [.coldDry], customTags: ["Gym"])
        let todays = DailyCheckIn(day: today, itch: 1, triggers: [.alcohol])
        let history = CheckInDraft.pickHistory(from: [older, todays, yesterday], before: today)
        #expect(history == [[.trigger(.coldDry), .custom("Gym")], [.trigger(.stress)]])
    }

    @Test func draftDiffersOnlyWhenEntriesChange() {
        let checkIn = DailyCheckIn(day: .now, itch: 4, triggers: [.stress], note: "Itchy")
        var draft = CheckInDraft(checkIn)
        draft.symptoms.fever = true
        draft.note = "Itchy "
        #expect(!draft.differs(from: checkIn))
        draft.itch = 5
        #expect(draft.differs(from: checkIn))
    }

    @Test func knownTagsAreNewestFirstWithoutDuplicates() {
        let calendar = Calendar.current
        let old = DailyCheckIn(day: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now, itch: 1, customTags: ["Gym", "Exams"])
        let recent = DailyCheckIn(day: .now, itch: 2, customTags: ["Hot shower", "gym"])
        #expect(CheckInDraft.knownTags(from: [old, recent]) == ["Hot shower", "gym", "Exams"])
    }
}
