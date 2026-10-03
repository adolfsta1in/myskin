import Foundation

/// Editable copy of a day's check-in. Optional scales stay nil until the user sets them,
/// so an untouched slider is not saved as 0.
struct CheckInDraft: Equatable {
    var itch = 0
    var pain: Int?
    var sleep: Int?
    var mood: Int?
    var triggers: Set<Trigger> = []
    /// User-defined tags, in the order they were added.
    var customTags: [String] = []
    var foods: Set<Food> = []
    /// User-defined foods, in the order they were added.
    var customFoods: [String] = []
    /// Whether food was logged at all. Untouched food is saved as nil (unknown), not as "nothing eaten".
    var foodLogged = false
    var newSpots = false
    var note = ""
    /// Flare-mode safety questions. Not stored: they are only used to check red flags on save.
    var symptoms = RedFlagSymptoms()
    /// Weather at save time; nil keeps what the check-in already has.
    var weather: WeatherReading?

    init() {}

    init(_ checkIn: DailyCheckIn) {
        itch = checkIn.itch
        pain = checkIn.pain
        sleep = checkIn.sleep
        mood = checkIn.mood
        triggers = Set(checkIn.triggers)
        customTags = checkIn.customTags
        foods = Set(checkIn.foods)
        customFoods = checkIn.customFoods
        foodLogged = checkIn.foodIDs != nil
        newSpots = checkIn.newSpots
        note = checkIn.note
    }

    /// Triggers in a stable order for storage.
    var orderedTriggers: [Trigger] { Trigger.allCases.filter(triggers.contains) }

    /// Foods in a stable order for storage.
    var orderedFoods: [Food] { Food.allCases.filter(foods.contains) }

    /// Stored `foodIDs`: nil while food wasn't logged.
    var foodIDs: [String]? { foodLogged ? orderedFoods.map(\.rawValue) : nil }

    /// "None of these" is shown selected when food was logged but nothing was picked.
    var isNoFood: Bool { foodLogged && foods.isEmpty && customFoods.isEmpty }

    func makeCheckIn(day: Date, calendar: Calendar = .current) -> DailyCheckIn {
        let checkIn = DailyCheckIn(
            day: day, itch: itch, pain: pain, sleep: sleep, mood: mood,
            triggers: orderedTriggers, customTags: customTags, newSpots: newSpots,
            note: trimmedNote, calendar: calendar
        )
        applyFood(to: checkIn)
        applyWeather(to: checkIn)
        return checkIn
    }

    private func applyFood(to checkIn: DailyCheckIn) {
        checkIn.foodIDs = foodIDs
        checkIn.customFoods = foodLogged ? customFoods : []
    }

    private func applyWeather(to checkIn: DailyCheckIn) {
        guard let weather else { return }
        checkIn.humidity = weather.humidity
        checkIn.uvIndex = weather.uvIndexMax
        checkIn.temperature = weather.temperature
    }

    /// The fields `FlareDetector` reads, for the live mode while editing.
    func sample(day: Date) -> CheckInSample {
        CheckInSample(day: day, itch: itch, newSpots: newSpots)
    }

    func apply(to checkIn: DailyCheckIn) {
        checkIn.itch = itch
        checkIn.pain = pain
        checkIn.sleep = sleep
        checkIn.mood = mood
        checkIn.triggers = orderedTriggers
        checkIn.customTags = customTags
        checkIn.newSpots = newSpots
        checkIn.note = trimmedNote
        applyFood(to: checkIn)
        applyWeather(to: checkIn)
        checkIn.updatedAt = .now
    }

    mutating func toggle(_ trigger: Trigger) {
        if triggers.contains(trigger) { triggers.remove(trigger) } else { triggers.insert(trigger) }
    }

    mutating func toggleCustomTag(_ tag: String) {
        if let index = customTags.firstIndex(of: tag) { customTags.remove(at: index) } else { customTags.append(tag) }
    }

    /// Adds and selects a typed tag. Empty input and case-insensitive duplicates are ignored;
    /// an existing tag with other casing is reused.
    mutating func addCustomTag(_ raw: String, known: [String] = []) {
        Self.add(raw, to: &customTags, known: known)
    }

    mutating func toggle(_ food: Food) {
        if foods.contains(food) { foods.remove(food) } else { foods.insert(food) }
        foodLogged = true
    }

    mutating func toggleCustomFood(_ food: String) {
        if let index = customFoods.firstIndex(of: food) { customFoods.remove(at: index) } else { customFoods.append(food) }
        foodLogged = true
    }

    /// Adds and selects a typed food, with the same rules as `addCustomTag`.
    mutating func addCustomFood(_ raw: String, known: [String] = []) {
        guard Self.add(raw, to: &customFoods, known: known) else { return }
        foodLogged = true
    }

    /// "None of these": food is logged, nothing picked.
    mutating func markNoFood() {
        foods = []
        customFoods = []
        foodLogged = true
    }

    /// Trims `raw` and appends it unless it is empty or already in `list` (case-insensitive).
    /// An entry from `list` or `known` with other casing is reused. Returns false for empty input.
    @discardableResult
    private static func add(_ raw: String, to list: inout [String], known: [String]) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let existing = (list + known).first { $0.caseInsensitiveCompare(value) == .orderedSame } ?? value
        if !list.contains(existing) { list.append(existing) }
        return true
    }

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Custom tags used before, newest first, without duplicates.
    static func knownTags(from checkIns: [DailyCheckIn]) -> [String] {
        known(checkIns, \.customTags)
    }

    /// Custom foods used before, newest first, without duplicates.
    static func knownFoods(from checkIns: [DailyCheckIn]) -> [String] {
        known(checkIns, \.customFoods)
    }

    private static func known(_ checkIns: [DailyCheckIn], _ values: KeyPath<DailyCheckIn, [String]>) -> [String] {
        var seen: Set<String> = []
        return checkIns
            .sorted { $0.day > $1.day }
            .flatMap { $0[keyPath: values] }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}
