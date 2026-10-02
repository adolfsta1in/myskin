import Foundation
import SwiftData

/// Full diary export as CSV files (one per record type). Photos are not included.
enum DataExport {
    /// One CSV table.
    struct Table: Equatable {
        let name: String
        let header: [String]
        let rows: [[String]]

        var csv: String {
            ([header] + rows).map { $0.map(CSV.escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        }
    }

    static func tables(in context: ModelContext) throws -> [Table] {
        let checkIns = try context.fetch(FetchDescriptor<DailyCheckIn>(sortBy: [SortDescriptor(\.day)]))
        let zones = try context.fetch(FetchDescriptor<ZoneAssessment>(sortBy: [SortDescriptor(\.day)]))
        let treatments = try context.fetch(FetchDescriptor<Treatment>(sortBy: [SortDescriptor(\.startDate)]))
        let doses = try context.fetch(FetchDescriptor<DoseLog>(sortBy: [SortDescriptor(\.timestamp)]))
        let results = try context.fetch(FetchDescriptor<QuestionnaireResult>(sortBy: [SortDescriptor(\.date)]))

        return [
            Table(
                name: "check-ins",
                header: ["date", "itch", "pain", "sleep", "mood", "new_spots", "triggers", "custom_tags", "note"],
                rows: checkIns.map {
                    [CSV.day($0.day), "\($0.itch)", CSV.optional($0.pain), CSV.optional($0.sleep), CSV.optional($0.mood),
                     $0.newSpots ? "yes" : "no", $0.triggerIDs.joined(separator: ";"), $0.customTags.joined(separator: ";"), $0.note]
                }
            ),
            Table(
                name: "zone-assessments",
                header: ["date", "zone_id", "zone", "palms", "redness", "thickness", "scaling", "pustules"],
                rows: zones.map {
                    [CSV.day($0.day), $0.zoneID, BodyZone.zone(id: $0.zoneID)?.name ?? "", CSV.number($0.palms),
                     "\($0.erythema)", "\($0.induration)", "\($0.scale)", $0.pustules ? "yes" : "no"]
                }
            ),
            Table(
                name: "treatments",
                header: ["name", "catalog_id", "kind", "steroid_class", "schedule", "zone_ids", "fingertip_units", "start", "end", "stop_reason", "notes"],
                rows: treatments.map {
                    [$0.name, $0.catalogID ?? "", $0.kindID, $0.steroidClassID ?? "", DoseScheduler.summary(for: $0.doseSchedule),
                     $0.zoneIDs.joined(separator: ";"), $0.fingertipUnits.map(CSV.number) ?? "", CSV.day($0.startDate),
                     $0.endDate.map(CSV.day) ?? "", $0.stopReason ?? "", $0.notes]
                }
            ),
            Table(
                name: "doses",
                header: ["treatment", "scheduled_at", "marked_at", "status", "injection_site", "fingertip_units", "note"],
                rows: doses.map {
                    [$0.treatment?.name ?? "", $0.scheduledAt.map(CSV.time) ?? "", CSV.time($0.timestamp), $0.statusID,
                     $0.injectionSiteID ?? "", $0.fingertipUnits.map(CSV.number) ?? "", $0.note]
                }
            ),
            Table(
                name: "questionnaires",
                header: ["date", "questionnaire", "score", "answers"],
                rows: results.map {
                    [CSV.time($0.date), $0.kindID, "\($0.score)", $0.answers.map(String.init).joined(separator: ";")]
                }
            ),
        ]
    }

    /// Writes the tables into the export folder and returns the file URLs.
    static func writeCSV(from context: ModelContext, folder: URL = ExportFolder.url, date: Date = .now) throws -> [URL] {
        let directory = try ExportFolder.prepare(folder)
        let stamp = ReportRenderer.fileDate(date)
        return try tables(in: context).map { table in
            let url = directory.appending(path: "MySkin \(table.name) \(stamp).csv")
            try Data(table.csv.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return url
        }
    }
}

enum CSV {
    /// Quotes a field if it contains a comma, quote or line break (RFC 4180).
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Local calendar day, e.g. `2026-10-02` (ISO 8601 formatting defaults to UTC, which shifts the day).
    static func day(_ date: Date) -> String { date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day()) }
    /// Local time with its offset, e.g. `2026-10-02T01:56:53+06:00`.
    static func time(_ date: Date) -> String { date.formatted(Date.ISO8601FormatStyle(timeZone: .current)) }
    static func optional(_ value: Int?) -> String { value.map(String.init) ?? "" }
    static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) }
}

/// «Delete all data»: every record, every photo file, exports, reminders and settings.
/// Afterwards the app shows onboarding again.
enum DataReset {
    static func deleteAll(context: ModelContext, photoStore: PhotoStore?, settings: AppSettings) throws {
        // Doses first: they belong to treatments.
        try deleteAll(DoseLog.self, in: context)
        try deleteAll(Treatment.self, in: context)
        try deleteAll(DailyCheckIn.self, in: context)
        try deleteAll(ZoneAssessment.self, in: context)
        try deleteAll(Photo.self, in: context)
        try deleteAll(QuestionnaireResult.self, in: context)
        try deleteAll(Profile.self, in: context)
        try context.save()

        try photoStore?.deleteAllFiles()
        ExportFolder.clear()
        settings.resetAll()
    }

    private static func deleteAll<Model: PersistentModel>(_ type: Model.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<Model>()) {
            context.delete(model)
        }
    }
}

extension PhotoStore {
    /// Removes every file in the photo folder; the folder itself stays.
    func deleteAllFiles() throws {
        let manager = FileManager.default
        for file in try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try manager.removeItem(at: file)
        }
    }
}
