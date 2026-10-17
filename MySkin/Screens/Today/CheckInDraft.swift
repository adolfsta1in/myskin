import Foundation

/// A draft whose chips can be picked in `LogPickerSheet`.
protocol PickDraft {
    func isSelected(_ pick: LogPick) -> Bool
    mutating func toggle(_ pick: LogPick)
    /// Adds and selects a typed entry; `known` reuses an existing spelling.
    mutating func addCustom(_ raw: String, known: [String])
}

/// Editable copy of a day's check-in. Optional scales stay nil until the user sets them,
/// so an untouched slider is not saved as 0. Food is logged separately (`FoodDraft`).
struct CheckInDraft: Equatable, PickDraft {
    var itch = 0
    var pain: Int?
    var sleep: Int?
    var mood: Int?
    var triggers: Set<Trigger> = []
    /// User-defined tags, in the order they were added.
    var customTags: [String] = []
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
        newSpots = checkIn.newSpots
        note = checkIn.note
    }

    var itchDescription: String {
        switch itch {
        case ..<1: String(localized: "Barely there")
        case ..<4: String(localized: "Noticeable")
        case ..<7: String(localized: "Hard to ignore")
        default: String(localized: "Very intense")
        }
    }

    /// Triggers in a stable order for storage.
    var orderedTriggers: [Trigger] { Trigger.allCases.filter(triggers.contains) }

    /// Today's picked triggers and tags as chips.
    var picks: [LogPick] { orderedTriggers.map(LogPick.trigger) + customTags.map(LogPick.custom) }

    /// Whether the entries differ from the stored check-in (safety answers and weather aren't stored).
    func differs(from checkIn: DailyCheckIn) -> Bool {
        var stored = CheckInDraft(checkIn)
        stored.symptoms = symptoms
        stored.weather = weather
        var current = self
        current.note = trimmedNote
        return current != stored
    }

    func makeCheckIn(day: Date, calendar: Calendar = .current) -> DailyCheckIn {
        let checkIn = DailyCheckIn(
            day: day, itch: itch, pain: pain, sleep: sleep, mood: mood,
            triggers: orderedTriggers, customTags: customTags, newSpots: newSpots,
            note: trimmedNote, calendar: calendar
        )
        applyWeather(to: checkIn)
        return checkIn
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

    func isSelected(_ pick: LogPick) -> Bool {
        switch pick {
        case .trigger(let trigger): triggers.contains(trigger)
        case .custom(let tag): customTags.contains(tag)
        case .food: false
        }
    }

    mutating func toggle(_ pick: LogPick) {
        switch pick {
        case .trigger(let trigger): toggle(trigger)
        case .custom(let tag): toggleCustomTag(tag)
        case .food: break
        }
    }

    mutating func addCustom(_ raw: String, known: [String]) {
        addCustomTag(raw, known: known)
    }

    /// Trims `raw` and appends it unless it is empty or already in `list` (case-insensitive).
    /// An entry from `list` or `known` with other casing is reused. Returns false for empty input.
    @discardableResult
    static func add(_ raw: String, to list: inout [String], known: [String]) -> Bool {
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

    /// Triggers and tags of check-ins before `day`, newest first — the input of `QuickPicks`.
    static func pickHistory(from checkIns: [DailyCheckIn], before day: Date) -> [[LogPick]] {
        checkIns
            .filter { $0.day < day }
            .sorted { $0.day > $1.day }
            // `QuickPicks` reads only the newest entries; drafts for the rest would be wasted on every redraw.
            .prefix(QuickPicks.Threshold.window)
            .map { CheckInDraft($0).picks }
    }

    static func known(_ checkIns: [DailyCheckIn], _ values: KeyPath<DailyCheckIn, [String]>) -> [String] {
        var seen: Set<String> = []
        return checkIns
            .sorted { $0.day > $1.day }
            .flatMap { $0[keyPath: values] }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}
