import Testing
@testable import MySkin

struct QuickPicksTests {
    private let defaults = ["a", "b", "c"]

    @Test func shortHistoryShowsDefaults() {
        let picks = QuickPicks.suggest(history: [["x"], ["x"]], defaults: defaults, selected: [])
        #expect(picks == defaults)
    }

    @Test func lastEntryComesFirstThenFrequent() {
        let history = [["new"], ["often", "rare"], ["often"], ["often"], ["second"], ["second"]]
        let picks = QuickPicks.suggest(history: history, defaults: defaults, selected: [])
        // "new" was logged last time; "often" (3×) before "second" (2×); "rare" (1×) is hidden.
        #expect(picks == ["new", "often", "second"])
    }

    @Test func unusedItemsAreHidden() {
        let history: [[String]] = [[], [], [], []]
        #expect(QuickPicks.suggest(history: history, defaults: defaults, selected: []).isEmpty)
    }

    @Test func selectedItemsAreAlwaysShown() {
        let history = [["a"], ["a"], ["a"]]
        let picks = QuickPicks.suggest(history: history, defaults: defaults, selected: ["a", "z"])
        #expect(picks == ["a", "z"])
    }

    @Test func tiesGoToTheMoreRecentItem() {
        let history = [[], ["late"], ["early"], ["late"], ["early"]]
        let picks = QuickPicks.suggest(history: history, defaults: defaults, selected: [])
        #expect(picks == ["late", "early"])
    }

    @Test func onlyRecentWindowCounts() {
        let old = Array(repeating: ["old"], count: 5)
        let recent: [[String]] = Array(repeating: [], count: QuickPicks.Threshold.window)
        #expect(QuickPicks.suggest(history: recent + old, defaults: defaults, selected: []).isEmpty)
    }

    @Test func suggestionsAreCapped() {
        let items = (0..<20).map { "item\($0)" }
        let history = [items, items, items]
        let picks = QuickPicks.suggest(history: history, defaults: defaults, selected: [])
        #expect(picks.count == QuickPicks.Threshold.limit)
    }
}
