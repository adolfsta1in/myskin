import Foundation
import SwiftData

/// Rewrites retired zone ids (C11.1: old neck zones, quick «Face») in stored data to the zones that
/// replaced them, so records use the current map. Runs on every store open; with nothing retired
/// left it only reads. Old palm ratings (`quick.palms`) stay: left or right is unknown.
enum RetiredZoneRepair {
    /// Retired ids that have a replacement.
    static let movedIDs: [String] = BodyZone.retired.map(\.id).filter { BodyZone.canonicalID($0) != $0 }

    /// - Returns: true if anything was changed.
    @discardableResult
    static func run(in context: ModelContext) throws -> Bool {
        var changed = try repairAssessments(in: context)

        for treatment in try context.fetch(FetchDescriptor<Treatment>()) where treatment.zoneIDs.contains(where: movedIDs.contains) {
            var seen: Set<String> = []
            treatment.zoneIDs = treatment.zoneIDs.map(BodyZone.canonicalID).filter { seen.insert($0).inserted }
            changed = true
        }

        // Photos keep their folder convention: the face is `quick.face`, old neck photos join `quick.neck`.
        for photo in try context.fetch(FetchDescriptor<Photo>()) {
            let folder = PhotoRecords.photoZoneID(photo.zoneID)
            if folder != photo.zoneID {
                photo.zoneID = folder
                changed = true
            }
        }

        if changed { try context.save() }
        return changed
    }

    /// Same-day ratings that land on one zone are merged like `DatedZoneScore.merged`:
    /// area adds up (capped at the zone's area), each sign takes the highest, pustules if any.
    private static func repairAssessments(in context: ModelContext) throws -> Bool {
        let moved = movedIDs
        let retired = try context.fetch(FetchDescriptor<ZoneAssessment>(
            predicate: #Predicate { moved.contains($0.zoneID) },
            sortBy: [SortDescriptor(\.day)]
        ))
        guard !retired.isEmpty else { return false }

        struct Key: Hashable { let day: Date; let zoneID: String }
        var current: [Key: ZoneAssessment] = [:]
        for record in try context.fetch(FetchDescriptor<ZoneAssessment>()) where !moved.contains(record.zoneID) {
            current[Key(day: record.day, zoneID: record.zoneID)] = record
        }

        for record in retired {
            let zoneID = BodyZone.canonicalID(record.zoneID)
            let key = Key(day: record.day, zoneID: zoneID)
            if let target = current[key] {
                let area = BodyZone.zone(id: zoneID)?.area ?? .infinity
                target.palms = min(target.palms + record.palms, area)
                target.erythema = max(target.erythema, record.erythema)
                target.induration = max(target.induration, record.induration)
                target.scale = max(target.scale, record.scale)
                target.pustules = target.pustules || record.pustules
                context.delete(record)
            } else {
                record.zoneID = zoneID
                current[key] = record
            }
        }
        return true
    }
}
