import Foundation
import SwiftData
import Testing
@testable import MyApp

struct DataExportTests {
    private func filledContext() throws -> ModelContext {
        let context = ModelContext(try AppModelContainer.makeInMemory())
        PreviewData.populate(context)
        try context.save()
        return context
    }

    @Test func csvEscaping() {
        #expect(CSV.escape("plain") == "plain")
        #expect(CSV.escape("a, b") == "\"a, b\"")
        #expect(CSV.escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSV.escape("two\nlines") == "\"two\nlines\"")
        #expect(CSV.number(0.5) == "0.5")
        #expect(CSV.number(1200) == "1200")
    }

    @Test func tablesCoverTheDiary() throws {
        let context = try filledContext()
        let tables = try DataExport.tables(in: context)
        #expect(tables.map(\.name) == ["check-ins", "zone-assessments", "treatments", "doses", "questionnaires"])
        #expect(tables[0].rows.count == 14)
        #expect(tables[1].rows.count == 12)
        #expect(tables[3].rows.count == 15)
        #expect(tables[4].rows.count == 3)
        for table in tables {
            #expect(table.rows.allSatisfy { $0.count == table.header.count })
        }
        // Stable ids plus a readable zone name.
        #expect(tables[1].rows.contains { $0[1] == "quick.scalp" && $0[2] == "Scalp" })
    }

    @Test func writesOneFilePerTable() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "DataExportTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = try DataExport.writeCSV(from: try filledContext(), folder: folder)
        #expect(urls.count == 5)
        let text = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(text.hasPrefix("date,itch,pain,sleep,mood,new_spots,triggers,custom_tags,note\r\n"))
    }

    @Test func deleteAllEmptiesEverything() async throws {
        let context = try filledContext()
        let photos = try PhotoStore(directory: FileManager.default.temporaryDirectory.appending(path: "DataResetTests-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: photos.directory) }
        try Data("x".utf8).write(to: photos.directory.appending(path: "a.jpg"))

        let settings = AppSettings(defaults: UserDefaults(suiteName: "DataResetTests-\(UUID().uuidString)") ?? .standard)
        settings.hasCompletedOnboarding = true
        settings.faceIDEnabled = true
        settings.checkInMinutes = 9 * 60

        try DataReset.deleteAll(context: context, photoStore: photos, settings: settings)

        #expect(try context.fetchCount(FetchDescriptor<DailyCheckIn>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ZoneAssessment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Treatment>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<DoseLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<QuestionnaireResult>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: photos.directory.path(percentEncoded: false)).isEmpty)
        #expect(!settings.hasCompletedOnboarding)
        #expect(!settings.faceIDEnabled)
        #expect(settings.checkInMinutes == 20 * 60)
    }
}
