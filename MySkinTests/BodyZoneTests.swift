import Testing
@testable import MyApp

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

    @Test func quickZonesAreTheSevenSpecialSites() {
        #expect(BodyZone.quickZones.map(\.id) == [
            "quick.scalp", "quick.face", "quick.nails", "quick.palms",
            "quick.soles", "quick.folds", "quick.genitals",
        ])
        #expect(BodyZone.quickZones.allSatisfy { $0.isSpecialSite })
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
