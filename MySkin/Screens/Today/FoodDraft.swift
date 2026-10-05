import Foundation

/// Editable food log of a day. It is stored on that day's `DailyCheckIn`, but edited
/// on its own card, so saving the check-in never overwrites it.
struct FoodDraft: Equatable, PickDraft {
    var foods: Set<Food> = []
    /// User-defined foods, in the order they were added.
    var customFoods: [String] = []
    /// Whether food was logged at all. Untouched food is saved as nil (unknown), not as "nothing eaten".
    var isLogged = false

    init() {}

    init(_ checkIn: DailyCheckIn) {
        foods = Set(checkIn.foods)
        customFoods = checkIn.customFoods
        isLogged = checkIn.foodIDs != nil
    }

    /// Foods in a stable order for storage.
    var orderedFoods: [Food] { Food.allCases.filter(foods.contains) }

    /// Stored `foodIDs`: nil while food wasn't logged.
    var foodIDs: [String]? { isLogged ? orderedFoods.map(\.rawValue) : nil }

    /// "None of these" is shown selected when food was logged but nothing was picked.
    var isNone: Bool { isLogged && foods.isEmpty && customFoods.isEmpty }

    /// Today's picked foods as chips.
    var picks: [LogPick] { orderedFoods.map(LogPick.food) + customFoods.map(LogPick.custom) }

    func apply(to checkIn: DailyCheckIn) {
        checkIn.foodIDs = foodIDs
        checkIn.customFoods = isLogged ? customFoods : []
        checkIn.updatedAt = .now
    }

    mutating func toggle(_ food: Food) {
        if foods.contains(food) { foods.remove(food) } else { foods.insert(food) }
        isLogged = true
    }

    mutating func toggleCustomFood(_ food: String) {
        if let index = customFoods.firstIndex(of: food) { customFoods.remove(at: index) } else { customFoods.append(food) }
        isLogged = true
    }

    /// Adds and selects a typed food, with the same rules as `CheckInDraft.addCustomTag`.
    mutating func addCustomFood(_ raw: String, known: [String] = []) {
        guard CheckInDraft.add(raw, to: &customFoods, known: known) else { return }
        isLogged = true
    }

    /// "None of these": food is logged, nothing picked.
    mutating func markNone() {
        foods = []
        customFoods = []
        isLogged = true
    }

    func isSelected(_ pick: LogPick) -> Bool {
        switch pick {
        case .food(let food): foods.contains(food)
        case .custom(let food): customFoods.contains(food)
        case .trigger: false
        }
    }

    mutating func toggle(_ pick: LogPick) {
        switch pick {
        case .food(let food): toggle(food)
        case .custom(let food): toggleCustomFood(food)
        case .trigger: break
        }
    }

    mutating func addCustom(_ raw: String, known: [String]) {
        addCustomFood(raw, known: known)
    }

    /// Custom foods used before, newest first, without duplicates.
    static func knownFoods(from checkIns: [DailyCheckIn]) -> [String] {
        CheckInDraft.known(checkIns, \.customFoods)
    }

    /// Foods of days before `day` where food was logged, newest first — the input of `QuickPicks`.
    /// Days without a food log are skipped: not logging is not "ate nothing".
    static func pickHistory(from checkIns: [DailyCheckIn], before day: Date) -> [[LogPick]] {
        checkIns
            .filter { $0.day < day && $0.foodIDs != nil }
            .sorted { $0.day > $1.day }
            .map { FoodDraft($0).picks }
    }
}
