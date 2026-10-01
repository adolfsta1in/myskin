import Foundation
import SwiftData
import Testing
@testable import MyApp

struct TreatmentDraftTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try AppModelContainer.makeInMemory())
    }

    @Test func catalogItemPrefillsSchedule() throws {
        let clobetasol = try #require(MedicationCatalog.medication(id: "clobetasol.ointment"))
        let draft = TreatmentDraft(medication: clobetasol)
        #expect(draft.catalogID == "clobetasol.ointment")
        #expect(draft.kind == .ointment)
        #expect(draft.steroidClass == .class1)
        #expect(draft.scheduleKind == .timesPerDay)
        #expect(draft.timesPerDay == 2)
        #expect(draft.doseMinutes == DoseScheduler.defaultMinutes(count: 2))
    }

    @Test func customNeedsAName() {
        #expect(!TreatmentDraft(customName: "   ").isValid)
        let draft = TreatmentDraft(customName: " Grandma's cream ")
        #expect(draft.isValid)
        #expect(draft.catalogID == nil)
        #expect(draft.trimmedName == "Grandma's cream")
    }

    @Test func catalogAndCustomSurviveReload() throws {
        let context = try makeContext()
        let clobetasol = try #require(MedicationCatalog.medication(id: "clobetasol.ointment"))
        var catalog = TreatmentDraft(medication: clobetasol)
        catalog.toggleZone("back.elbow.left")
        catalog.fingertipUnits = 1
        context.insert(catalog.makeTreatment())
        context.insert(TreatmentDraft(customName: "Grandma's cream").makeTreatment())
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Treatment>(sortBy: [SortDescriptor(\.name)]))
        #expect(stored.map(\.name) == ["Clobetasol propionate 0.05% ointment", "Grandma's cream"])
        let reloaded = TreatmentDraft(stored[0])
        #expect(reloaded.zoneIDs == ["back.elbow.left"])
        #expect(reloaded.fingertipUnits == 1)
        #expect(reloaded.steroidClass == .class1)
        #expect(stored[1].catalogID == nil)
    }

    @Test func editingUpdatesInPlace() throws {
        let context = try makeContext()
        let treatment = TreatmentDraft(customName: "Cream").makeTreatment()
        context.insert(treatment)
        var draft = TreatmentDraft(treatment)
        draft.timesPerDay = 3
        draft.apply(to: treatment)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Treatment>()) == 1)
        #expect(treatment.timesPerDay == 3)
        #expect(treatment.doseMinutes.count == 3)
    }

    @Test func stopAndResume() {
        let treatment = TreatmentDraft(customName: "Cream").makeTreatment()
        TreatmentDraft.stop(treatment, reason: " Skin cleared ")
        #expect(!treatment.isActive)
        #expect(treatment.stopReason == "Skin cleared")
        TreatmentDraft.resume(treatment)
        #expect(treatment.isActive)
        #expect(treatment.stopReason == nil)
    }

    @Test func nonTopicalsDropAreasAndStrength() {
        var draft = TreatmentDraft(customName: "Tablet")
        draft.toggleZone("quick.scalp")
        draft.steroidClass = .class4
        draft.fingertipUnits = 2
        draft.kind = .pill
        let treatment = draft.makeTreatment()
        #expect(treatment.zoneIDs.isEmpty)
        #expect(treatment.steroidClass == nil)
        #expect(treatment.fingertipUnits == nil)
    }

    @Test func strongSteroidOnFaceWarns() throws {
        let clobetasol = try #require(MedicationCatalog.medication(id: "clobetasol.ointment"))
        var draft = TreatmentDraft(medication: clobetasol)
        draft.toggleZone("back.elbow.left")
        #expect(draft.sensitiveAreaWarning == nil)
        draft.toggleZone("quick.face")
        #expect(draft.sensitiveAreaWarning?.contains("Face") == true)
        draft.steroidClass = .class6
        #expect(draft.sensitiveAreaWarning == nil)
    }

    @Test func searchIsCaseInsensitive() {
        #expect(TreatmentDraft.search("CLOBETASOL").count >= 2)
        #expect(TreatmentDraft.search("").count == MedicationCatalog.all.count)
        #expect(TreatmentDraft.search("zzz").isEmpty)
    }
}
