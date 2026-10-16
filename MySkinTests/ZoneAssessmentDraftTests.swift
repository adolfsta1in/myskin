import Foundation
import SwiftData
import Testing
@testable import MySkin

struct ZoneAssessmentDraftTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    private func all(_ context: ModelContext) throws -> [ZoneAssessment] {
        try context.fetch(FetchDescriptor<ZoneAssessment>())
    }

    @Test func saveThenReloadKeepsValues() throws {
        let context = try makeContext()
        var draft = ZoneAssessmentDraft()
        draft.palms = 1.5
        draft.erythema = 3
        draft.induration = 2
        draft.scale = 1
        draft.pustules = true
        try draft.save(zoneID: "back.elbow.left", day: .now, in: context)

        let stored = try #require(ZoneAssessmentDraft.latest(zoneID: "back.elbow.left", in: try all(context)))
        #expect(ZoneAssessmentDraft(stored.score) == draft)
    }

    @Test func savingTwiceADayUpdatesOneRecord() throws {
        let context = try makeContext()
        var draft = ZoneAssessmentDraft()
        draft.palms = 1
        try draft.save(zoneID: "front.knee.left", day: .now, in: context)
        draft.palms = 2
        try draft.save(zoneID: "front.knee.left", day: .now, in: context)

        let records = try all(context)
        #expect(records.count == 1)
        #expect(records.first?.palms == 2)
    }

    @Test func newDayAddsRecordAndLatestWins() throws {
        let context = try makeContext()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        var draft = ZoneAssessmentDraft()
        draft.erythema = 3
        try draft.save(zoneID: "quick.scalp", day: yesterday, in: context)
        draft.erythema = 1
        try draft.save(zoneID: "quick.scalp", day: .now, in: context)

        let records = try all(context)
        #expect(records.count == 2)
        #expect(ZoneAssessmentDraft.latest(zoneID: "quick.scalp", in: records)?.erythema == 1)
    }

    @Test func ratingTheFaceReplacesTheOldQuickFaceRecordOfThatDay() throws {
        let context = try makeContext()
        context.insert(ZoneAssessment(day: .now, zoneID: "quick.face", palms: 1, erythema: 2))
        try context.save()
        // The old quick «Face» rating shows as the face on the map.
        #expect(ZoneAssessmentDraft.latest(zoneID: "front.head", in: try all(context))?.erythema == 2)
        #expect(try all(context).first?.score.zoneID == "front.head")

        var draft = ZoneAssessmentDraft()
        draft.erythema = 1
        try draft.save(zoneID: "front.head", day: .now, in: context)
        let records = try all(context)
        #expect(records.map(\.zoneID) == ["front.head"])
        #expect(records.first?.erythema == 1)
    }

    @Test func clearedZoneIsStoredAsClear() throws {
        let context = try makeContext()
        var draft = ZoneAssessmentDraft()
        draft.palms = 1
        try draft.save(zoneID: "quick.nails", day: .now, in: context)
        try ZoneAssessmentDraft().save(zoneID: "quick.nails", day: .now, in: context)

        let stored = try #require(try all(context).first)
        #expect(!stored.score.isAffected)
    }

    @Test func palmsRangeFollowsZoneArea() throws {
        let nails = try #require(BodyZone.zone(id: "quick.nails"))
        let chest = try #require(BodyZone.zone(id: "front.torso.upper"))
        #expect(ZoneAssessmentDraft.palmsRange(for: nails).upperBound == nails.area)
        #expect(ZoneAssessmentDraft.palmsRange(for: chest).upperBound == chest.area)
        #expect(ZoneAssessmentDraft.palmsStep(for: nails) < ZoneAssessmentDraft.palmsStep(for: chest))
    }
}
