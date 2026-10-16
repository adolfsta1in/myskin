import Testing
@testable import MySkin

struct BodyZoneTests {
    @Test func zoneIDsAreUnique() {
        let ids = BodyZone.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyZoneHasPositiveArea() {
        #expect(BodyZone.all.allSatisfy { $0.area > 0 })
    }

    @Test func everyRegionIsUsed() {
        // Each zone has a region by type; make sure all four regions are covered.
        #expect(Set(BodyZone.all.map(\.region)) == Set(BodyRegion.allCases))
    }

    @Test func quickZones() {
        #expect(BodyZone.quickZones.map(\.id) == [
            "quick.scalp", "quick.neck", "quick.nails",
            "quick.soles", "quick.folds", "quick.genitals",
        ])
        // All special sites except the neck, which is here only because it's hard to tap.
        #expect(BodyZone.quickZones.filter { !$0.isSpecialSite }.map(\.id) == ["quick.neck"])
    }

    @Test func faceAndPalmsAreOnTheSilhouetteOnly() {
        #expect(BodyZone.zone(id: "quick.face") == nil)
        #expect(BodyZone.zone(id: "quick.palms") == nil)
        #expect(BodyZone.zone(id: "front.neck") == nil)
        #expect(BodyZone.zone(id: "front.head")?.name == "Face")
        #expect(BodyZone.zone(id: "front.hand.left")?.name == "Left palm")
        #expect(BodyZone.zone(id: "front.hand.left")?.isSpecialSite == true)
        #expect(BodyZone.zone(id: "back.hand.left")?.name == "Left hand")
        #expect(BodyZone.zone(id: "back.hand.left")?.isSpecialSite == false)
    }

    @Test func retiredZonesKeepNamesAndMoveToTheirReplacement() {
        #expect(BodyZone.named(id: "quick.face")?.name == "Face")
        #expect(BodyZone.named(id: "quick.palms")?.name == "Palms")
        #expect(BodyZone.canonicalID("quick.face") == "front.head")
        #expect(BodyZone.canonicalID("front.neck") == "quick.neck")
        #expect(BodyZone.canonicalID("back.neck") == "quick.neck")
        #expect(BodyZone.canonicalID("front.elbow.left") == "front.elbow.left")
        let retiredIDs = Set(BodyZone.retired.map(\.id))
        #expect(BodyZone.all.allSatisfy { !retiredIDs.contains($0.id) })
    }

    @Test func silhouetteZonesKeepStableIDs() {
        // Spot-check ids already used by stored data and mocks.
        for id in ["front.elbow.left", "back.elbow.right", "front.knee.right", "back.torso.lower", "front.head"] {
            #expect(BodyZone.zone(id: id) != nil, "Missing zone \(id)")
        }
        #expect(BodyZone.zone(id: "front.elbow.left")?.region == .arms)
        #expect(BodyZone.zone(id: "back.pelvis")?.region == .legs)
    }
}
