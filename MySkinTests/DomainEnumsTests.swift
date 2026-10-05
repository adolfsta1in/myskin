import Testing
@testable import MySkin

/// Raw values are stored on disk. These tests fail if a case is renamed or removed by accident.
struct DomainEnumsTests {
    @Test func profileEnumRawValues() {
        #expect(Sex.allCases.map(\.rawValue) == ["female", "male", "other"])
        #expect(ArthritisStatus.allCases.map(\.rawValue) == ["diagnosed", "suspected", "no", "unsure"])
    }

    @Test func psoriasisTypeRawValues() {
        #expect(PsoriasisType.allCases.map(\.rawValue) == [
            "plaque", "guttate", "inverse", "pustular", "palmoplantar", "nail", "scalp", "genital",
        ])
    }

    @Test func triggerRawValues() {
        #expect(Trigger.allCases.map(\.rawValue) == [
            "stress", "alcohol", "smoking", "infection", "skinInjury", "newMedication", "sunburn", "coldDry",
        ])
    }

    @Test func foodRawValues() {
        #expect(Food.allCases.map(\.rawValue) == [
            "dairy", "gluten", "sugar", "redMeat", "processed", "nightshades", "spicy", "coffee",
        ])
    }

    @Test func treatmentKindRawValues() {
        #expect(TreatmentKind.allCases.map(\.rawValue) == [
            "cream", "ointment", "shampoo", "foam", "pill", "biologic", "phototherapy",
        ])
    }

    @Test func steroidClassRawValues() {
        #expect(SteroidClass.allCases.map(\.rawValue) == [
            "class1", "class2", "class3", "class4", "class5", "class6", "class7",
        ])
        #expect(SteroidClass.allCases.map(\.number) == Array(1...7))
    }

    @Test func scheduleKindRawValues() {
        #expect(ScheduleKind.allCases.map(\.rawValue) == [
            "timesPerDay", "weekly", "everyNDays", "everyNWeeks", "asNeeded",
        ])
    }

    @Test func questionnaireKindRawValues() {
        #expect(QuestionnaireKind.allCases.map(\.rawValue) == ["dlqi", "pest"])
    }

    @Test func doseStatusRawValues() {
        #expect(DoseStatus.allCases.map(\.rawValue) == ["done", "skipped"])
    }
}
