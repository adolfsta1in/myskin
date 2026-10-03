import Foundation
import SwiftData
import Testing
@testable import MyApp

/// A store written by the V1 app must open as V2 without losing data.
struct MigrationTests {
    @Test func v1StoreOpensAsV2() throws {
        let folder = URL.temporaryDirectory.appending(path: "migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "MySkin.store")
        let day = Calendar.current.startOfDay(for: .now)

        // Write with the old schema only.
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            context.insert(SchemaV1.Profile(psoriasisTypes: [.plaque], onsetYear: 2015))
            context.insert(SchemaV1.DailyCheckIn(day: day, itch: 6, triggers: [.stress], note: "old"))
            let treatment = SchemaV1.Treatment(name: "Calcipotriol", kind: .cream, scheduleKind: .timesPerDay)
            context.insert(treatment)
            context.insert(SchemaV1.DoseLog(treatment: treatment, status: .done))
            try context.save()
        }

        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: MySkinMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
        let context = ModelContext(container)

        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.psoriasisTypes == [.plaque])
        #expect(profile.onsetYear == 2015)
        #expect(profile.name == "")
        #expect(profile.sex == nil)
        #expect(profile.arthritisStatus == nil)

        let checkIn = try #require(try context.fetch(FetchDescriptor<DailyCheckIn>()).first)
        #expect(checkIn.itch == 6)
        #expect(checkIn.triggers == [.stress])
        #expect(checkIn.note == "old")
        #expect(checkIn.humidity == nil)
        #expect(checkIn.uvIndex == nil)

        let migrated = try #require(try context.fetch(FetchDescriptor<Treatment>()).first)
        #expect(migrated.name == "Calcipotriol")
        #expect(migrated.doses.count == 1)
    }

    @Test func newRecordsGetASyncID() {
        let first = DailyCheckIn(day: .now, itch: 1)
        let second = DailyCheckIn(day: .now, itch: 1)
        #expect(first.syncID != nil)
        #expect(first.syncID != second.syncID)
    }
}
