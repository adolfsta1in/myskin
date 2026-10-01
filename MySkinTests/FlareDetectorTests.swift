import Foundation
import Testing
@testable import MyApp

struct FlareDetectorTests {
    /// Fixed calendar and date so the tests do not depend on the machine's time zone.
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

    /// Check-ins for the given day offsets with the same itch.
    private func checkIns(_ offsets: ClosedRange<Int>, itch: Int) -> [CheckInSample] {
        offsets.map { CheckInSample(day: day($0), itch: itch) }
    }

    private func status(_ checkIns: [CheckInSample], zones: [DatedZoneScore] = []) -> FlareStatus {
        FlareDetector.status(on: today, checkIns: checkIns, zones: zones, calendar: calendar)
    }

    // MARK: - Not enough data

    @Test func fewerThanThreeCheckInsIsCalm() {
        #expect(status([CheckInSample(day: day(-1), itch: 9), CheckInSample(day: today, itch: 10)]) == .calm)
    }

    @Test func noDataIsCalm() {
        #expect(status([]) == .calm)
    }

    @Test func quietWeekIsCalm() {
        #expect(status(checkIns(-6...0, itch: 2)) == .calm)
    }

    // MARK: - Itch

    @Test func highItchTodayIsFlare() {
        let result = status(checkIns(-6...(-1), itch: 6) + [CheckInSample(day: today, itch: 7)])
        #expect(result.mode == .flare)
        #expect(result.reasons == [.highItch(7)])
        #expect(result.signalDay == calendar.startOfDay(for: today))
    }

    @Test func highItchYesterdayIsFlare() {
        let result = status(checkIns(-6...(-2), itch: 5) + [CheckInSample(day: day(-1), itch: 8), CheckInSample(day: today, itch: 5)])
        #expect(result.mode == .flare)
        #expect(result.reasons.contains(.highItch(8)))
        #expect(result.signalDay == calendar.startOfDay(for: day(-1)))
    }

    @Test func itchSpikeAboveAverageIsFlare() {
        let result = status(checkIns(-5...(-1), itch: 2) + [CheckInSample(day: today, itch: 5)])
        #expect(result.mode == .flare)
        #expect(result.reasons == [.itchSpike(itch: 5, average: 2)])
    }

    @Test func smallerRiseIsCalm() {
        #expect(status(checkIns(-5...(-1), itch: 2) + [CheckInSample(day: today, itch: 4)]) == .calm)
    }

    @Test func spikeNeedsThreeRecentCheckIns() {
        // Enough check-ins overall, but only two in the 7-day window.
        let old = checkIns(-20...(-19), itch: 1)
        let recent = checkIns(-2...(-1), itch: 1)
        #expect(status(old + recent + [CheckInSample(day: today, itch: 5)]) == .calm)
    }

    @Test func newSpotsIsFlare() {
        let result = status(checkIns(-3...(-1), itch: 2) + [CheckInSample(day: today, itch: 2, newSpots: true)])
        #expect(result.reasons == [.newSpots])
    }

    // MARK: - Body map

    @Test func bsaIncreaseIsFlare() {
        let zones = [
            DatedZoneScore(day: day(-5), score: ZoneScore(zoneID: "front.thigh.left", palms: 1, erythema: 2)),
            DatedZoneScore(day: today, score: ZoneScore(zoneID: "front.thigh.left", palms: 2.5, erythema: 2)),
        ]
        let result = status(checkIns(-6...0, itch: 2), zones: zones)
        #expect(result.mode == .flare)
        #expect(result.reasons == [.bsaIncrease(from: 1, to: 2.5)])
    }

    @Test func smallBSAChangeIsCalm() {
        let zones = [
            DatedZoneScore(day: day(-5), score: ZoneScore(zoneID: "front.thigh.left", palms: 1, erythema: 2)),
            DatedZoneScore(day: today, score: ZoneScore(zoneID: "front.thigh.left", palms: 1.5, erythema: 2)),
        ]
        #expect(status(checkIns(-6...0, itch: 2), zones: zones) == .calm)
    }

    @Test func newZoneIsFlare() {
        // Only the elbow is updated today; the thigh carries over from the last map.
        let zones = [
            DatedZoneScore(day: day(-5), score: ZoneScore(zoneID: "front.thigh.left", palms: 1, erythema: 2)),
            DatedZoneScore(day: today, score: ZoneScore(zoneID: "front.elbow.left", palms: 0.4, erythema: 1)),
        ]
        let result = status(checkIns(-6...0, itch: 2), zones: zones)
        #expect(result.reasons == [.newZones(["front.elbow.left"])])
    }

    @Test func firstMapIsNotAFlare() {
        let zones = [DatedZoneScore(day: today, score: ZoneScore(zoneID: "front.torso.upper", palms: 9, erythema: 3))]
        #expect(status(checkIns(-6...0, itch: 2), zones: zones) == .calm)
    }

    // MARK: - Back to Calm

    @Test func calmAfterThreeDaysWithoutSigns() {
        let flareThreeDaysAgo = checkIns(-9...(-4), itch: 2) + [CheckInSample(day: day(-3), itch: 9)] + checkIns(-2...0, itch: 2)
        #expect(status(flareThreeDaysAgo) == .calm)

        let flareTwoDaysAgo = checkIns(-9...(-3), itch: 2) + [CheckInSample(day: day(-2), itch: 9)] + checkIns(-1...0, itch: 2)
        #expect(status(flareTwoDaysAgo).mode == .flare)
    }

    @Test func futureCheckInsAreIgnored() {
        #expect(status(checkIns(-6...0, itch: 2) + [CheckInSample(day: day(1), itch: 10)]) == .calm)
    }

    @Test func reasonsHaveExplanations() {
        let reasons: [FlareReason] = [.highItch(8), .itchSpike(itch: 6, average: 2), .bsaIncrease(from: 1, to: 3), .newZones(["front.elbow.left"]), .newSpots]
        #expect(reasons.allSatisfy { !$0.explanation.isEmpty })
        #expect(FlareReason.newZones(["front.elbow.left"]).explanation.contains("Left elbow"))
    }
}
