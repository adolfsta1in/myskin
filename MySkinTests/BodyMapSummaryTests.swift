import Foundation
import Testing
@testable import MySkin

struct BodyMapSummaryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12)) ?? .now
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func entry(_ offset: Int, _ zoneID: String, palms: Double, signs: Int = 2) -> DatedZoneScore {
        DatedZoneScore(day: day(offset), score: ZoneScore(zoneID: zoneID, palms: palms, erythema: signs, induration: signs, scale: signs))
    }

    @Test func sameDayRetiredNeckRatingsAreMerged() {
        // Front and back of the neck from before they became one quick zone.
        let zones = DatedZoneScore.merged([
            DatedZoneScore(day: day(0), score: ZoneScore(zoneID: BodyZone.canonicalID("front.neck"), palms: 1, erythema: 1)),
            DatedZoneScore(day: day(0), score: ZoneScore(zoneID: BodyZone.canonicalID("back.neck"), palms: 0.5, erythema: 3, pustules: true)),
            entry(0, "front.elbow.left", palms: 1),
        ], calendar: calendar)
        #expect(zones.count == 2)
        let neck = zones.first { $0.score.zoneID == "quick.neck" }?.score
        #expect(neck?.palms == 1.5)
        #expect(neck?.erythema == 3)
        #expect(neck?.pustules == true)
        let summary = BodyMapSummary.make(zones: zones, calendar: calendar)
        #expect(abs(summary.snapshot.bsa - 1.9) < 0.001)
    }

    @Test func ratingsOnDifferentDaysAreNotMerged() {
        let zones = DatedZoneScore.merged([entry(-1, "quick.neck", palms: 1), entry(0, "quick.neck", palms: 0.5)], calendar: calendar)
        #expect(zones.count == 2)
    }

    @Test func emptyWithoutAssessments() {
        #expect(BodyMapSummary.make(zones: [], calendar: calendar) == .empty)
    }

    @Test func firstMapHasNoPrevious() {
        let summary = BodyMapSummary.make(zones: [entry(0, "front.torso.upper", palms: 1)], calendar: calendar)
        #expect(summary.previous == nil)
        #expect(summary.bsaChange == nil)
        #expect(summary.snapshot.bsa == 1)
    }

    @Test func changeIsAgainstMapBeforeLatestDay() {
        let zones = [
            entry(-7, "front.torso.upper", palms: 2),
            entry(-7, "back.torso.upper", palms: 1),
            entry(0, "front.torso.upper", palms: 1),
        ]
        let summary = BodyMapSummary.make(zones: zones, calendar: calendar)
        // The back keeps its earlier score: 1 + 1 now, 2 + 1 before.
        #expect(summary.snapshot.bsa == 2)
        #expect(summary.previous?.bsa == 3)
        #expect(summary.bsaChange == -1)
        #expect(summary.lastAssessed == calendar.startOfDay(for: today))
    }

    @Test func clearedZoneHasNoColor() {
        let zones = [entry(-1, "back.elbow.left", palms: 1), entry(0, "back.elbow.left", palms: 0, signs: 0)]
        let summary = BodyMapSummary.make(zones: zones, calendar: calendar)
        #expect(summary.levels.isEmpty)
        #expect(summary.snapshot.bsa == 0)
    }

    @Test func specialSiteIsElevated() {
        let summary = BodyMapSummary.make(zones: [entry(0, "quick.scalp", palms: 0.5)], calendar: calendar)
        #expect(summary.snapshot.isElevated)
        #expect(summary.snapshot.specialSiteIDs == ["quick.scalp"])
    }

    @Test func jointSymptomsAreElevated() {
        let summary = BodyMapSummary.make(zones: [entry(0, "back.elbow.left", palms: 1)], arthritisSuspected: true, calendar: calendar)
        #expect(summary.snapshot.isElevated)
        #expect(summary.snapshot.category == .moderate)
    }

    @Test(arguments: [(0, 0, 0, 0.0, 0), (0, 0, 0, 1.0, 1), (1, 1, 1, 1.0, 1), (2, 2, 1, 1.0, 2), (2, 2, 2, 1.0, 2), (3, 3, 2, 1.0, 3), (4, 4, 4, 1.0, 3)])
    func levels(erythema: Int, induration: Int, scale: Int, palms: Double, expected: Int) {
        let score = ZoneScore(zoneID: "back.elbow.left", palms: palms, erythema: erythema, induration: induration, scale: scale)
        #expect(SeverityCalculator.level(for: score) == expected)
    }
}
