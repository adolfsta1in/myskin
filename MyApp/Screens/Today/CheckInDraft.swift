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
    var newSpots = false
    var note = ""

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

    /// Triggers in a stable order for storage.
    var orderedTriggers: [Trigger] { Trigger.allCases.filter(triggers.contains) }

    func makeCheckIn(day: Date, calendar: Calendar = .current) -> DailyCheckIn {
        DailyCheckIn(
            day: day, itch: itch, pain: pain, sleep: sleep, mood: mood,
            triggers: orderedTriggers, customTags: customTags, newSpots: newSpots,
            note: trimmedNote, calendar: calendar
        )
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
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        let existing = (customTags + known).first { $0.caseInsensitiveCompare(tag) == .orderedSame } ?? tag
        if !customTags.contains(existing) { customTags.append(existing) }
    }

    private var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Custom tags used before, newest first, without duplicates.
    static func knownTags(from checkIns: [DailyCheckIn]) -> [String] {
        var seen: Set<String> = []
        return checkIns
            .sorted { $0.day > $1.day }
            .flatMap(\.customTags)
            .filter { seen.insert($0.lowercased()).inserted }
    }
}
