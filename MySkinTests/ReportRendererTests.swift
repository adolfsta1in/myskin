import Foundation
import PDFKit
import Testing
@testable import MyApp

struct ReportRendererTests {
    @Test func writesAOnePagePDF() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ReportRendererTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let report = DoctorReport.make(
            periodDays: 30, endingOn: .now, psoriasisTypes: [.plaque],
            checkIns: [DailyCheckInSample(day: .now, itch: 4, triggers: [.stress])],
            zones: [DatedZoneScore(day: .now, score: ZoneScore(zoneID: "quick.scalp", palms: 1, erythema: 2))],
            results: [(.dlqi, .now, 6)], treatments: [], photos: []
        )
        let url = try ReportRenderer.makePDF(report: report, weeklyItch: [], images: [:], folder: folder)

        #expect(url.pathExtension == "pdf")
        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount == 1)
        let text = document.string ?? ""
        #expect(text.contains("Skin summary"))
        #expect(text.contains("DLQI"))
        #expect(document.page(at: 0)?.bounds(for: .mediaBox).width == ReportRenderer.pageWidth)
    }

    @Test func prepareEmptiesTheFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "ExportFolderTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try ExportFolder.prepare(folder)
        try Data("old".utf8).write(to: folder.appending(path: "old.csv"))
        try ExportFolder.prepare(folder)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).isEmpty)
    }
}
