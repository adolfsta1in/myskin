import Foundation
import SwiftData

/// Editable copy of one zone's assessment. A zone keeps one record per day; saving again the
/// same day updates it, so history keeps the last value of each day.
struct ZoneAssessmentDraft: Equatable {
    var palms = 0.0
    var erythema = 0
    var induration = 0
    var scale = 0
    var pustules = false

    init() {}

    init(_ score: ZoneScore) {
        palms = score.palms
        erythema = score.erythema
        induration = score.induration
        scale = score.scale
        pustules = score.pustules
    }

    /// Nothing marked: saving it records the zone as clear.
    var isClear: Bool { palms == 0 && erythema == 0 && induration == 0 && scale == 0 && !pustules }

    func score(zoneID: String) -> ZoneScore {
        ZoneScore(zoneID: zoneID, palms: palms, erythema: erythema, induration: induration, scale: scale, pustules: pustules)
    }

    /// Area slider bounds: up to the zone's reference area, in steps that suit its size.
    static func palmsRange(for zone: BodyZone) -> ClosedRange<Double> { 0...max(zone.area, 0.1) }
    static func palmsStep(for zone: BodyZone) -> Double { zone.area <= 1 ? 0.1 : 0.5 }

    /// Inserts or updates the record for `zoneID` on `day` and saves the context.
    func save(zoneID: String, day: Date, in context: ModelContext, calendar: Calendar = .current) throws {
        let start = calendar.startOfDay(for: day)
        let descriptor = FetchDescriptor<ZoneAssessment>(predicate: #Predicate { $0.day == start && $0.zoneID == zoneID })
        if let existing = try context.fetch(descriptor).first {
            existing.palms = palms
            existing.erythema = erythema
            existing.induration = induration
            existing.scale = scale
            existing.pustules = pustules
        } else {
            context.insert(ZoneAssessment(
                day: start, zoneID: zoneID, palms: palms,
                erythema: erythema, induration: induration, scale: scale, pustules: pustules,
                calendar: calendar
            ))
        }
        try context.save()
    }

    /// Latest stored state of a zone, if it was ever assessed.
    static func latest(zoneID: String, in assessments: [ZoneAssessment]) -> ZoneAssessment? {
        assessments.filter { $0.zoneID == zoneID }.max { $0.day < $1.day }
    }
}

/// Labels for the 0–4 sign scales, shared by the sheet and summaries.
enum SignScale {
    static func label(for value: Int) -> String {
        switch value {
        case 1: "Slight"
        case 2: "Moderate"
        case 3: "Marked"
        case 4: "Very marked"
        default: "None"
        }
    }
}
