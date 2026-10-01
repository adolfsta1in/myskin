import Foundation
import Testing
@testable import MyApp

struct RedFlagRulesTests {
    /// Both thighs and the chest: 18 % of the body.
    private func pustularZones() -> [ZoneScore] {
        ["front.thigh.left", "front.thigh.right", "front.torso.upper"].compactMap(BodyZone.zone(id:)).map {
            ZoneScore(zoneID: $0.id, palms: $0.area, erythema: 2, pustules: true)
        }
    }

    /// Every silhouette zone red; `share` of each zone's area.
    private func redBody(share: Double) -> [ZoneScore] {
        (BodyZone.frontZones + BodyZone.backZones).map {
            ZoneScore(zoneID: $0.id, palms: $0.area * share, erythema: 2, scale: 2)
        }
    }

    // MARK: - Pustules

    @Test func widespreadPustulesWithFeverIsFlag() {
        #expect(RedFlagRules.flags(zones: pustularZones(), symptoms: RedFlagSymptoms(fever: true)) == [.widespreadPustules])
    }

    @Test func widespreadPustulesWhenUnwellIsFlag() {
        #expect(RedFlagRules.flags(zones: pustularZones(), symptoms: RedFlagSymptoms(feelsUnwell: true)) == [.widespreadPustules])
    }

    @Test func pustulesWithoutFeverAreNotAFlag() {
        #expect(RedFlagRules.flags(zones: pustularZones(), symptoms: RedFlagSymptoms()).isEmpty)
    }

    @Test func palmAndSolePustulesWithFeverAreNotAFlag() {
        let zones = [
            ZoneScore(zoneID: "quick.palms", palms: 1, pustules: true),
            ZoneScore(zoneID: "quick.soles", palms: 1, pustules: true),
        ]
        #expect(RedFlagRules.flags(zones: zones, symptoms: RedFlagSymptoms(fever: true)).isEmpty)
    }

    // MARK: - Redness

    @Test func rednessOverThreeQuartersIsFlag() {
        #expect(RedFlagRules.flags(zones: redBody(share: 0.8), symptoms: RedFlagSymptoms()) == [.widespreadRedness])
    }

    @Test func rednessBelowThresholdIsNotAFlag() {
        #expect(RedFlagRules.flags(zones: redBody(share: 0.7), symptoms: RedFlagSymptoms(chills: true)).isEmpty)
    }

    @Test func scaleWithoutRednessDoesNotCount() {
        let zones = (BodyZone.frontZones + BodyZone.backZones).map { ZoneScore(zoneID: $0.id, palms: $0.area, scale: 2) }
        #expect(RedFlagRules.flags(zones: zones, symptoms: RedFlagSymptoms()).isEmpty)
    }

    // MARK: - Steroid withdrawal

    @Test func flareAfterStoppingSteroidsIsFlag() {
        let symptoms = RedFlagSymptoms(stoppedSystemicSteroids: true)
        #expect(RedFlagRules.flags(zones: [], symptoms: symptoms, isFlare: true) == [.flareAfterSteroidWithdrawal])
        #expect(RedFlagRules.flags(zones: [], symptoms: symptoms, isFlare: false).isEmpty)
    }

    // MARK: - Ordinary day

    @Test func ordinaryCheckInHasNoFlags() {
        let zones = [
            ZoneScore(zoneID: "front.elbow.left", palms: 0.4, erythema: 2, induration: 2, scale: 2),
            ZoneScore(zoneID: "quick.scalp", palms: 1, erythema: 1, scale: 2),
        ]
        #expect(RedFlagRules.flags(zones: zones, symptoms: RedFlagSymptoms(), isFlare: true).isEmpty)
        #expect(RedFlagRules.flags(zones: [], symptoms: RedFlagSymptoms()).isEmpty)
    }

    @Test func everyFlagHasNeutralText() {
        for flag in RedFlag.allCases {
            #expect(!flag.message.isEmpty)
            #expect(!flag.message.localizedCaseInsensitiveContains("psoriasis"))
        }
    }
}
