import Foundation
import SwiftData
import Testing
@testable import MyApp

struct PersistenceTests {
    /// Fresh in-memory store for each test.
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    @Test func previewDataPopulates() throws {
        let context = try makeContext()
        PreviewData.populate(context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Profile>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DailyCheckIn>()) == 14)
        #expect(try context.fetchCount(FetchDescriptor<SchemaV1.Treatment>()) == 4)
    }

    /// Today's mode comes from stored data: the regular sample is Calm, the flare sample is Flare.
    @Test func previewDataModes() throws {
        let calm = try makeContext()
        PreviewData.populate(calm)
        let flare = try makeContext()
        PreviewData.populate(flare, flare: true)

        func status(_ context: ModelContext) throws -> FlareStatus {
            FlareDetector.status(
                on: .now,
                checkIns: try context.fetch(FetchDescriptor<DailyCheckIn>()),
                assessments: try context.fetch(FetchDescriptor<ZoneAssessment>())
            )
        }
        #expect(try status(calm).mode == .calm)
        let flareStatus = try status(flare)
        #expect(flareStatus.mode == .flare)
        #expect(flareStatus.reasons.contains(.highItch(8)))
    }

    @Test func profileRoundTrip() throws {
        let context = try makeContext()
        context.insert(Profile(psoriasisTypes: [.plaque, .scalp], onsetYear: 2015, goals: [.doctor], baselineSelfRating: 0.4))
        try context.save()

        let profiles = try context.fetch(FetchDescriptor<Profile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.psoriasisTypes == [.plaque, .scalp])
        #expect(profiles.first?.psoriasisTypeIDs == ["plaque", "scalp"])
        #expect(profiles.first?.goals == [.doctor])
        #expect(profiles.first?.onsetYear == 2015)
    }

    @Test func checkInRoundTripNormalisesDay() throws {
        let context = try makeContext()
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: .now) ?? .now
        context.insert(DailyCheckIn(day: afternoon, itch: 6, pain: 2, triggers: [.stress, .coldDry], customTags: ["Exams"], newSpots: true))
        try context.save()

        let checkIns = try context.fetch(FetchDescriptor<DailyCheckIn>())
        #expect(checkIns.count == 1)
        let checkIn = try #require(checkIns.first)
        #expect(checkIn.day == Calendar.current.startOfDay(for: afternoon))
        #expect(checkIn.itch == 6)
        #expect(checkIn.triggers == [.stress, .coldDry])
        #expect(checkIn.customTags == ["Exams"])
        #expect(checkIn.newSpots)
    }

    @Test func zoneAssessmentRoundTrip() throws {
        let context = try makeContext()
        context.insert(ZoneAssessment(day: .now, zoneID: "front.elbow.left", palms: 0.5, erythema: 3, induration: 2, scale: 1))
        try context.save()

        let assessments = try context.fetch(FetchDescriptor<ZoneAssessment>())
        #expect(assessments.count == 1)
        let assessment = try #require(assessments.first)
        #expect(assessment.zoneID == "front.elbow.left")
        #expect(assessment.palms == 0.5)
        #expect(assessment.erythema == 3)
        #expect(!assessment.pustules)
    }

    @Test func treatmentOwnsDoseLogs() throws {
        let context = try makeContext()
        let treatment = SchemaV1.Treatment(
            name: "Clobetasol", kind: .ointment, steroidClass: .class1,
            scheduleKind: .timesPerDay, timesPerDay: 2, zoneIDs: ["front.knee.left"]
        )
        context.insert(treatment)
        context.insert(DoseLog(treatment: treatment, status: .done))
        context.insert(DoseLog(treatment: treatment, status: .skipped))
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SchemaV1.Treatment>()).first)
        #expect(fetched.doses.count == 2)
        #expect(fetched.kind == .ointment)
        #expect(fetched.steroidClass == .class1)
        #expect(Set(fetched.doses.map(\.status)) == [.done, .skipped])
        #expect(try context.fetch(FetchDescriptor<DoseLog>()).allSatisfy { $0.treatment === fetched })
    }

    @Test func deletingTreatmentDeletesItsDoses() throws {
        let context = try makeContext()
        let kept = SchemaV1.Treatment(name: "Adalimumab", kind: .biologic, scheduleKind: .everyNWeeks, interval: 2)
        let removed = SchemaV1.Treatment(name: "Calcipotriol", kind: .cream, scheduleKind: .timesPerDay)
        context.insert(kept)
        context.insert(removed)
        context.insert(DoseLog(treatment: kept, status: .done, injectionSite: .abdomenLeft))
        context.insert(DoseLog(treatment: removed, status: .done))
        context.insert(DoseLog(treatment: removed, status: .done))
        try context.save()

        context.delete(removed)
        try context.save()

        let doses = try context.fetch(FetchDescriptor<DoseLog>())
        #expect(doses.count == 1)
        #expect(doses.first?.injectionSite == .abdomenLeft)
        #expect(try context.fetch(FetchDescriptor<SchemaV1.Treatment>()).map(\.name) == ["Adalimumab"])
    }

    @Test func photoAndQuestionnaireRoundTrip() throws {
        let context = try makeContext()
        context.insert(Photo(day: .now, zoneID: "quick.scalp", fileName: "A1B2.jpg"))
        context.insert(QuestionnaireResult(kind: .pest, answers: [1, 0, 1, 1, 0], score: 3))
        try context.save()

        let photo = try #require(try context.fetch(FetchDescriptor<Photo>()).first)
        #expect(photo.zoneID == "quick.scalp")
        #expect(photo.fileName == "A1B2.jpg")

        let pestKind = QuestionnaireKind.pest.rawValue
        let results = try context.fetch(FetchDescriptor<QuestionnaireResult>(predicate: #Predicate { $0.kindID == pestKind }))
        #expect(results.count == 1)
        #expect(results.first?.score == 3)
        #expect(results.first?.kind == .pest)
    }
}
