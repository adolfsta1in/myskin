import Foundation

/// One chip in a check-in list: a built-in trigger or food, or the user's own tag.
nonisolated enum LogPick: Hashable, Sendable {
    case trigger(Trigger)
    case food(Food)
    case custom(String)

    var title: String {
        switch self {
        case .trigger(let trigger): trigger.title
        case .food(let food): food.title
        case .custom(let text): text
        }
    }
}

/// Which chips the check-in shows up front: what was logged last time and what is logged often.
/// Everything else stays in the full list behind "More".
nonisolated enum QuickPicks {
    enum Threshold {
        /// Past entries looked at, newest first.
        static let window = 14
        /// With fewer past entries the defaults are shown, so a new user sees the full set.
        static let minHistory = 3
        /// Uses in the window for an item to count as "often".
        static let minUses = 2
        /// Suggested chips at most; picked items are always shown on top of this.
        static let limit = 8
    }

    /// - Parameters:
    ///   - history: selections of past entries, newest first (today excluded).
    ///   - defaults: shown while there is too little history.
    ///   - selected: today's picks — always shown, appended if not suggested.
    static func suggest<Item: Hashable>(history: [[Item]], defaults: [Item], selected: [Item]) -> [Item] {
        let recent = Array(history.prefix(Threshold.window))
        var result: [Item]
        if recent.count < Threshold.minHistory {
            result = defaults
        } else {
            var counts: [Item: Int] = [:]
            // Index of the newest entry with the item, to break ties by recency.
            var newest: [Item: Int] = [:]
            for (index, entry) in recent.enumerated() {
                for item in Set(entry) {
                    counts[item, default: 0] += 1
                    if newest[item] == nil { newest[item] = index }
                }
            }
            let frequent = counts
                .filter { $0.value >= Threshold.minUses }
                .map(\.key)
                .sorted { (counts[$0] ?? 0, -(newest[$0] ?? 0)) > (counts[$1] ?? 0, -(newest[$1] ?? 0)) }
            result = []
            for item in unique(recent[0]) + frequent where !result.contains(item) {
                result.append(item)
            }
            result = Array(result.prefix(Threshold.limit))
        }
        for item in selected where !result.contains(item) {
            result.append(item)
        }
        return result
    }

    private static func unique<Item: Hashable>(_ items: [Item]) -> [Item] {
        var seen: Set<Item> = []
        return items.filter { seen.insert($0).inserted }
    }
}
