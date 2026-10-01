import Foundation

/// Editable copy of a treatment. Starts from a catalog item, a custom name, or a stored `Treatment`.
struct TreatmentDraft: Hashable {
    var name = ""
    var catalogID: String?
    var kind: TreatmentKind = .cream
    var steroidClass: SteroidClass?
    var scheduleKind: ScheduleKind = .timesPerDay
    var timesPerDay = 1 {
        didSet { syncDoseMinutes() }
    }
    var interval = 1
    /// 1 = Sunday … 7 = Saturday; nil uses the start date's weekday.
    var weekday: Int?
    /// Minutes after midnight; kept in step with `timesPerDay`.
    var doseMinutes: [Int] = DoseScheduler.defaultMinutes(count: 1)
    var fingertipUnits: Double?
    /// `BodyZone.id` values in `BodyZone.all` order.
    var zoneIDs: [String] = []
    var startDate = Date.now
    var notes = ""

    init() {}

    /// Custom medication typed by the user.
    init(customName: String) {
        name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Catalog item with its typical schedule as a starting point.
    init(medication: Medication) {
        name = medication.name
        catalogID = medication.id
        kind = medication.kind
        steroidClass = medication.steroidClass
        scheduleKind = medication.schedule.kind
        interval = medication.schedule.interval
        timesPerDay = medication.schedule.timesPerDay
        syncDoseMinutes()
    }

    init(_ treatment: Treatment) {
        name = treatment.name
        catalogID = treatment.catalogID
        kind = treatment.kind
        steroidClass = treatment.steroidClass
        scheduleKind = treatment.scheduleKind
        timesPerDay = treatment.timesPerDay
        interval = treatment.interval
        weekday = treatment.weekday
        doseMinutes = DoseScheduler.minutes(for: treatment.doseSchedule)
        fingertipUnits = treatment.fingertipUnits
        zoneIDs = treatment.zoneIDs
        startDate = treatment.startDate
        notes = treatment.notes
    }

    var medication: Medication? { catalogID.flatMap(MedicationCatalog.medication(id:)) }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValid: Bool { !trimmedName.isEmpty && timesPerDay >= 1 && interval >= 1 }

    /// Topicals are applied to areas and measured in fingertip units.
    var isTopical: Bool { [.cream, .ointment, .foam, .shampoo].contains(kind) }

    /// Number of reminder times the schedule needs.
    var timeCount: Int {
        switch scheduleKind {
        case .timesPerDay: timesPerDay
        case .weekly, .everyNDays, .everyNWeeks: 1
        case .asNeeded: 0
        }
    }

    var schedule: DoseSchedule {
        DoseSchedule(
            kind: scheduleKind, timesPerDay: timesPerDay, interval: interval, weekday: weekday,
            doseMinutes: Array(doseMinutes.prefix(timeCount)), startDate: startDate
        )
    }

    /// Strong steroid (class I–II) on the face, skin folds or genitals: worth checking with the doctor (spec §2.4).
    var sensitiveAreaWarning: String? {
        guard isTopical, let steroidClass, steroidClass.number <= 2 else { return nil }
        let sensitive = zoneIDs.filter(Self.sensitiveZoneIDs.contains).compactMap { BodyZone.zone(id: $0)?.name }
        guard !sensitive.isEmpty else { return nil }
        return "Strong steroids on \(sensitive.formatted(.list(type: .and))) can thin the skin. Check with your doctor that this is intended."
    }

    static let sensitiveZoneIDs: Set<String> = ["front.head", "quick.face", "quick.folds", "quick.genitals"]

    mutating func toggleZone(_ id: String) {
        var ids = Set(zoneIDs)
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        zoneIDs = BodyZone.all.map(\.id).filter(ids.contains)
    }

    /// Changing the count resets times to the defaults, so slots never get out of step.
    private mutating func syncDoseMinutes() {
        let count = max(timesPerDay, 1)
        if doseMinutes.count != count {
            doseMinutes = DoseScheduler.defaultMinutes(count: count)
        }
    }

    // MARK: - Storage

    func makeTreatment() -> Treatment {
        let treatment = Treatment(name: trimmedName, kind: kind, scheduleKind: scheduleKind)
        apply(to: treatment)
        return treatment
    }

    func apply(to treatment: Treatment) {
        treatment.name = trimmedName
        treatment.catalogID = catalogID
        treatment.kind = kind
        treatment.steroidClass = isTopical ? steroidClass : nil
        treatment.scheduleKind = scheduleKind
        treatment.timesPerDay = timesPerDay
        treatment.interval = interval
        treatment.weekday = scheduleKind == .weekly ? weekday : nil
        treatment.doseMinutes = Array(doseMinutes.prefix(timeCount))
        treatment.fingertipUnits = isTopical ? fingertipUnits : nil
        treatment.zoneIDs = isTopical ? zoneIDs : []
        treatment.startDate = startDate
        treatment.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ends the treatment now; reminders stop from this moment.
    static func stop(_ treatment: Treatment, reason: String, at date: Date = .now) {
        treatment.endDate = date
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        treatment.stopReason = trimmed.isEmpty ? nil : trimmed
    }

    static func resume(_ treatment: Treatment) {
        treatment.endDate = nil
        treatment.stopReason = nil
    }

    /// Catalog search by name, case- and diacritic-insensitive. Empty query returns everything.
    static func search(_ query: String) -> [Medication] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MedicationCatalog.all }
        return MedicationCatalog.all.filter {
            $0.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
