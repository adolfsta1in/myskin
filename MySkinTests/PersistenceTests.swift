import Foundation
import SwiftData
import Testing
@testable import MyApp

struct PersistenceTests {
    /// Fresh in-memory store for each test.
    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
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
}
