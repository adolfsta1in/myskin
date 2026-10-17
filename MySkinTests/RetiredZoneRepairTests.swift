import Foundation
import SwiftData
import Testing
@testable import MySkin

struct RetiredZoneRepairTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_790_000_000))

    @Test func retiredAssessmentsMoveAndMergeOnTheSameDay() throws {
        let context = try makeContext()
        context.insert(ZoneAssessment(day: day, zoneID: "front.neck", palms: 1, erythema: 1))
        context.insert(ZoneAssessment(day: day, zoneID: "back.neck", palms: 0.8, erythema: 3, pustules: true))
        context.insert(ZoneAssessment(day: day, zoneID: "quick.face", palms: 1, scale: 2))
        context.insert(ZoneAssessment(day: day, zoneID: "front.head", palms: 0.5, scale: 1))
        context.insert(ZoneAssessment(day: day.addingTimeInterval(-86_400), zoneID: "front.neck", palms: 0.5))
        context.insert(ZoneAssessment(day: day, zoneID: "quick.palms", palms: 0.5))
        try context.save()

        #expect(try RetiredZoneRepair.run(in: context))
        let records = try context.fetch(FetchDescriptor<ZoneAssessment>())
        let ids = records.map(\.zoneID)
        #expect(!ids.contains("front.neck") && !ids.contains("back.neck") && !ids.contains("quick.face"))
        // Old palms have no single replacement and stay.
        #expect(ids.contains("quick.palms"))

        let neck = try #require(records.first { $0.zoneID == "quick.neck" && $0.day == day })
        #expect(abs(neck.palms - 1.8) < 0.001)
        #expect(neck.erythema == 3)
        #expect(neck.pustules)
        #expect(records.filter { $0.zoneID == "quick.neck" }.count == 2)

        let face = try #require(records.first { $0.zoneID == "front.head" })
        #expect(face.scale == 2)
        #expect(records.filter { $0.zoneID == "front.head" }.count == 1)

        // Second run: nothing left to do.
        #expect(try !RetiredZoneRepair.run(in: context))
    }

    @Test func mergedAreaIsCappedAtTheZoneArea() throws {
        let context = try makeContext()
        context.insert(ZoneAssessment(day: day, zoneID: "front.neck", palms: 1))
        context.insert(ZoneAssessment(day: day, zoneID: "back.neck", palms: 1))
        context.insert(ZoneAssessment(day: day, zoneID: "quick.neck", palms: 1.5))
        try context.save()
        try RetiredZoneRepair.run(in: context)
        let neck = try #require(try context.fetch(FetchDescriptor<ZoneAssessment>()).first)
        #expect(neck.palms == 2)
    }

    @Test func treatmentsAndPhotosUseCurrentZones() throws {
        let context = try makeContext()
        let treatment = Treatment(name: "Cream", kind: .cream, scheduleKind: .timesPerDay, zoneIDs: ["quick.face", "front.head", "front.neck"])
        context.insert(treatment)
        let neckPhoto = Photo(day: day, zoneID: "back.neck", fileName: "a.jpg")
        let facePhoto = Photo(day: day, zoneID: "quick.face", fileName: "b.jpg")
        context.insert(neckPhoto)
        context.insert(facePhoto)
        try context.save()

        #expect(try RetiredZoneRepair.run(in: context))
        #expect(treatment.zoneIDs == ["front.head", "quick.neck"])
        #expect(neckPhoto.zoneID == "quick.neck")
        // Face photos stay in the face folder.
        #expect(facePhoto.zoneID == "quick.face")
    }
}
