import Testing
@testable import MyApp

struct SeverityCalculatorTests {
    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.000_1 }

    /// Every zone fully affected with the given signs.
    private func allZones(sign: Int) -> [ZoneScore] {
        BodyZone.all.map { ZoneScore(zoneID: $0.id, palms: $0.area, erythema: sign, induration: sign, scale: sign) }
    }

    // MARK: - Empty data

    @Test func emptyDataIsMildAndZero() {
        #expect(SeverityCalculator.snapshot(for: [ZoneScore]()) == .empty)
    }

    @Test func clearZonesDoNotCount() {
        let scores = [ZoneScore(zoneID: "quick.scalp", palms: 0), ZoneScore(zoneID: "front.elbow.left", palms: 0)]
        #expect(SeverityCalculator.snapshot(for: scores) == .empty)
    }

    @Test func unknownZonesAreIgnored() {
        let snapshot = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "front.tail", palms: 5, erythema: 4)])
        #expect(snapshot == .empty)
    }

    // MARK: - Area limits

    @Test func zoneAreaIsCapped() {
        // Elbow is 0.4 % of the body; 5 palms cannot fit there.
        let snapshot = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "front.elbow.left", palms: 5, erythema: 1)])
        #expect(isClose(snapshot.bsa, 0.4))
    }

    @Test func negativeAreaCountsAsZero() {
        let snapshot = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "front.thigh.left", palms: -3, erythema: 2)])
        #expect(snapshot.bsa == 0)
        #expect(snapshot.severityIndex == 0)
    }

    @Test func overlappingQuickZonesAreCappedByRegion() {
        // `front.head` («Face») and `quick.face` overlap; head region is 11 % in total.
        let headIDs = ["front.head", "back.head", "front.neck", "back.neck", "quick.face", "quick.scalp"]
        let scores = headIDs.compactMap(BodyZone.zone(id:)).map { ZoneScore(zoneID: $0.id, palms: $0.area, erythema: 1) }
        let snapshot = SeverityCalculator.snapshot(for: scores)
        #expect(isClose(snapshot.bsa, 11))
    }

    @Test func wholeBodyIsAtMostHundredPercentAndIndex72() {
        let snapshot = SeverityCalculator.snapshot(for: allZones(sign: 4))
        #expect(isClose(snapshot.bsa, 100))
        #expect(isClose(snapshot.severityIndex, 72))
        #expect(snapshot.category == .severe)
    }

    @Test func duplicateZoneUsesLastScore() {
        let scores = [
            ZoneScore(zoneID: "front.thigh.left", palms: 4, erythema: 4),
            ZoneScore(zoneID: "front.thigh.left", palms: 1, erythema: 1),
        ]
        #expect(isClose(SeverityCalculator.snapshot(for: scores).bsa, 1))
    }

    // MARK: - Severity index

    @Test func severityIndexForOneZone() {
        // Arms: 0.4 of 18 % → area score 1; signs 2+3+1 = 6; weight 0.2 → 1.2.
        let score = ZoneScore(zoneID: "front.elbow.left", palms: 0.4, erythema: 2, induration: 3, scale: 1)
        #expect(isClose(SeverityCalculator.snapshot(for: [score]).severityIndex, 1.2))
    }

    @Test func signsAreClampedToFour() {
        let score = ZoneScore(zoneID: "front.elbow.left", palms: 0.4, erythema: 9, induration: 9, scale: 9)
        #expect(isClose(SeverityCalculator.snapshot(for: [score]).severityIndex, 0.2 * 12 * 1))
    }

    @Test(arguments: [(0.0, 0), (5.0, 1), (10.0, 2), (29.9, 2), (30.0, 3), (50.0, 4), (70.0, 5), (89.9, 5), (90.0, 6), (100.0, 6)])
    func areaScoreBands(percent: Double, expected: Int) {
        #expect(SeverityCalculator.areaScore(percent: percent) == expected)
    }

    // MARK: - Rule of tens

    @Test(arguments: [(2.9, SeverityCategory.mild), (3.0, .moderate), (10.0, .moderate), (10.1, .severe)])
    func bsaBands(bsa: Double, expected: SeverityCategory) {
        #expect(SeverityCalculator.baseCategory(bsa: bsa, severityIndex: 0, dlqi: nil) == expected)
    }

    @Test func severityIndexAboveTenIsSevere() {
        #expect(SeverityCalculator.baseCategory(bsa: 1, severityIndex: 10, dlqi: nil) == .mild)
        #expect(SeverityCalculator.baseCategory(bsa: 1, severityIndex: 10.1, dlqi: nil) == .severe)
    }

    @Test func dlqiAboveTenIsSevere() {
        #expect(SeverityCalculator.snapshot(for: [ZoneScore](), dlqi: 10).category == .mild)
        #expect(SeverityCalculator.snapshot(for: [ZoneScore](), dlqi: 11).category == .severe)
    }

    // MARK: - Special sites

    @Test func specialSiteUpgradesMildToModerate() {
        let plain = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "front.elbow.left", palms: 0.4, scale: 2)])
        #expect(plain.category == .mild)
        #expect(!plain.isElevated)

        let scalp = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "quick.scalp", palms: 0.4, scale: 2)])
        #expect(scalp.bsa < SeverityCalculator.Threshold.mildBSA)
        #expect(scalp.category == .moderate)
        #expect(scalp.isElevated)
        #expect(scalp.specialSiteIDs == ["quick.scalp"])
    }

    @Test func faceOnSilhouetteIsSpecialSite() {
        let face = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "front.head", palms: 0.5, erythema: 1)])
        #expect(face.specialSiteIDs == ["front.head"])
        #expect(face.category == .moderate)

        let backOfHead = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "back.head", palms: 0.5, erythema: 1)])
        #expect(backOfHead.specialSiteIDs.isEmpty)
        #expect(backOfHead.category == .mild)
    }

    @Test func nailsWithoutAreaStillCountAsSpecialSite() {
        let snapshot = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "quick.nails", palms: 0, scale: 1)])
        #expect(snapshot.specialSiteIDs == ["quick.nails"])
        #expect(snapshot.category == .moderate)
    }

    @Test func specialSiteDoesNotLowerSevere() {
        let snapshot = SeverityCalculator.snapshot(for: [ZoneScore(zoneID: "quick.palms", palms: 1, erythema: 1)], dlqi: 15)
        #expect(snapshot.category == .severe)
        #expect(snapshot.isElevated)
    }

    @Test func arthritisUpgradesMildToModerate() {
        let snapshot = SeverityCalculator.snapshot(for: [ZoneScore](), arthritisSuspected: true)
        #expect(snapshot.category == .moderate)
        #expect(snapshot.isElevated)
        #expect(snapshot.specialSiteIDs.isEmpty)
    }

    @Test func specialSitesFollowZoneOrder() {
        let scores = [ZoneScore(zoneID: "quick.genitals", palms: 0.5), ZoneScore(zoneID: "quick.scalp", palms: 0.5)]
        #expect(SeverityCalculator.snapshot(for: scores).specialSiteIDs == ["quick.scalp", "quick.genitals"])
    }
}
