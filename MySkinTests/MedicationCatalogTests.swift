import Testing
@testable import MyApp

struct MedicationCatalogTests {
    @Test func idsAreUnique() {
        let ids = MedicationCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func catalogHasAboutThirtyItems() {
        #expect(MedicationCatalog.all.count >= 30)
        #expect(MedicationCatalog.all.allSatisfy { !$0.name.isEmpty })
    }

    @Test func everySteroidHasAClass() {
        for item in MedicationCatalog.all where item.category.containsSteroid {
            #expect(item.steroidClass != nil, "\(item.id) has no steroid class")
            #expect(item.kind.isTopical, "\(item.id) should be topical")
        }
    }

    @Test func nonSteroidsHaveNoClass() {
        for item in MedicationCatalog.all where !item.category.containsSteroid {
            #expect(item.steroidClass == nil, "\(item.id) should not have a steroid class")
        }
    }

    @Test func everyBiologicHasAnInterval() {
        let biologics = MedicationCatalog.all.filter { $0.kind == .biologic }
        #expect(!biologics.isEmpty)
        for item in biologics {
            #expect(item.schedule.kind == .everyNWeeks, "\(item.id) needs an every-N-weeks schedule")
            #expect(item.schedule.interval >= 1, "\(item.id) needs an interval")
        }
    }

    @Test func schedulesAreValid() {
        for item in MedicationCatalog.all {
            #expect(item.schedule.timesPerDay >= 1)
            #expect(item.schedule.interval >= 1)
        }
    }

    @Test func everyCategoryIsUsed() {
        #expect(Set(MedicationCatalog.all.map(\.category)) == Set(MedicationCategory.allCases))
    }

    @Test func keyItemsKeepStableIDsAndRules() {
        // Methotrexate must never be daily.
        #expect(MedicationCatalog.medication(id: "methotrexate")?.schedule.kind == .weekly)
        #expect(MedicationCatalog.medication(id: "icotrokinra")?.notes.contains("empty stomach") == true)
        #expect(MedicationCatalog.medication(id: "risankizumab")?.schedule.interval == 12)
        #expect(MedicationCatalog.medication(id: "clobetasol.ointment")?.steroidClass == .class1)
        #expect(MedicationCatalog.medication(id: "unknown") == nil)
    }
}
