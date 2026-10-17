import Foundation

// Built-in list of common psoriasis medications. Lives in code, not in the database:
// `Treatment.catalogID` stores `Medication.id`, so ids must never be renamed or reused.
// Schedules are typical maintenance regimens, a starting point the user can change —
// not a prescription.

nonisolated enum MedicationCategory: String, CaseIterable, Identifiable, Sendable {
    case topicalSteroid, steroidVitaminD, vitaminD, nonSteroidalTopical, calcineurinInhibitor
    case tarAndKeratolytic, emollient, conventionalOral, targetedOral, biologic, phototherapy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topicalSteroid: String(localized: "Steroid creams & ointments")
        case .steroidVitaminD: String(localized: "Steroid + vitamin D")
        case .vitaminD: String(localized: "Vitamin D creams")
        case .nonSteroidalTopical: String(localized: "Non-steroid creams")
        case .calcineurinInhibitor: String(localized: "Calcineurin inhibitors")
        case .tarAndKeratolytic: String(localized: "Tar & scale softeners")
        case .emollient: String(localized: "Moisturisers")
        case .conventionalOral: String(localized: "Tablets")
        case .targetedOral: String(localized: "Targeted tablets")
        case .biologic: String(localized: "Biologics")
        case .phototherapy: String(localized: "Phototherapy")
        }
    }

    /// Items in these categories must have a `SteroidClass`.
    var containsSteroid: Bool { self == .topicalSteroid || self == .steroidVitaminD }
}

nonisolated struct TypicalSchedule: Hashable, Sendable {
    let kind: ScheduleKind
    var timesPerDay: Int = 1
    /// N for `everyNDays` / `everyNWeeks`.
    var interval: Int = 1

    static func daily(_ times: Int) -> TypicalSchedule { TypicalSchedule(kind: .timesPerDay, timesPerDay: times) }
    static func everyWeeks(_ weeks: Int) -> TypicalSchedule { TypicalSchedule(kind: .everyNWeeks, interval: weeks) }
    static func everyDays(_ days: Int) -> TypicalSchedule { TypicalSchedule(kind: .everyNDays, interval: days) }
    static let weekly = TypicalSchedule(kind: .weekly)
    static let asNeeded = TypicalSchedule(kind: .asNeeded)
}

nonisolated struct Medication: Identifiable, Hashable, Sendable {
    /// Stable id stored in `Treatment.catalogID`. Never rename.
    let id: String
    let name: String
    let kind: TreatmentKind
    let category: MedicationCategory
    var steroidClass: SteroidClass? = nil
    let schedule: TypicalSchedule
    /// Short practical note, e.g. "Once a week". Empty if nothing special.
    var notes: String = ""
}

nonisolated enum MedicationCatalog {
    static let all: [Medication] = topicals + orals + biologics + phototherapy

    static func medication(id: String) -> Medication? { all.first { $0.id == id } }

    static func items(in category: MedicationCategory) -> [Medication] { all.filter { $0.category == category } }

    // MARK: - Topicals

    private static let topicals: [Medication] = [
        // Steroids, US potency classes I (strongest) … VII.
        Medication(id: "clobetasol.ointment", name: String(localized: "Clobetasol propionate 0.05% ointment"), kind: .ointment, category: .topicalSteroid, steroidClass: .class1, schedule: .daily(2),
                   notes: String(localized: "Very strong. Usually short courses; not for the face or skin folds unless your doctor says so.")),
        Medication(id: "clobetasol.shampoo", name: String(localized: "Clobetasol propionate 0.05% shampoo"), kind: .shampoo, category: .topicalSteroid, steroidClass: .class1, schedule: .daily(1),
                   notes: String(localized: "Apply to dry scalp, leave for 15 minutes, then rinse.")),
        Medication(id: "betamethasone.dipropionate.ointment", name: String(localized: "Betamethasone dipropionate 0.05% ointment"), kind: .ointment, category: .topicalSteroid, steroidClass: .class2, schedule: .daily(1)),
        Medication(id: "fluocinonide.cream", name: String(localized: "Fluocinonide 0.05% cream"), kind: .cream, category: .topicalSteroid, steroidClass: .class2, schedule: .daily(2)),
        Medication(id: "mometasone.cream", name: String(localized: "Mometasone furoate 0.1% cream"), kind: .cream, category: .topicalSteroid, steroidClass: .class4, schedule: .daily(1)),
        Medication(id: "triamcinolone.cream", name: String(localized: "Triamcinolone acetonide 0.1% cream"), kind: .cream, category: .topicalSteroid, steroidClass: .class4, schedule: .daily(2)),
        Medication(id: "betamethasone.valerate.cream", name: String(localized: "Betamethasone valerate 0.1% cream"), kind: .cream, category: .topicalSteroid, steroidClass: .class5, schedule: .daily(2)),
        Medication(id: "desonide.cream", name: String(localized: "Desonide 0.05% cream"), kind: .cream, category: .topicalSteroid, steroidClass: .class6, schedule: .daily(2),
                   notes: String(localized: "Mild; often used on the face and skin folds.")),
        Medication(id: "hydrocortisone.cream", name: String(localized: "Hydrocortisone 1% cream"), kind: .cream, category: .topicalSteroid, steroidClass: .class7, schedule: .daily(2)),
        Medication(id: "calcipotriol.betamethasone", name: String(localized: "Calcipotriol + betamethasone (Daivobet, Taclonex)"), kind: .ointment, category: .steroidVitaminD, steroidClass: .class2, schedule: .daily(1)),

        Medication(id: "calcipotriol.cream", name: String(localized: "Calcipotriol (calcipotriene) 0.005% cream"), kind: .cream, category: .vitaminD, schedule: .daily(2)),
        Medication(id: "calcitriol.ointment", name: String(localized: "Calcitriol ointment"), kind: .ointment, category: .vitaminD, schedule: .daily(2)),
        Medication(id: "roflumilast.cream", name: String(localized: "Roflumilast 0.3% cream (Zoryve)"), kind: .cream, category: .nonSteroidalTopical, schedule: .daily(1)),
        Medication(id: "tapinarof.cream", name: String(localized: "Tapinarof 1% cream (Vtama)"), kind: .cream, category: .nonSteroidalTopical, schedule: .daily(1)),
        Medication(id: "tacrolimus.ointment", name: String(localized: "Tacrolimus 0.1% ointment"), kind: .ointment, category: .calcineurinInhibitor, schedule: .daily(2),
                   notes: String(localized: "Often used on the face and skin folds.")),
        Medication(id: "coaltar.shampoo", name: String(localized: "Coal tar shampoo"), kind: .shampoo, category: .tarAndKeratolytic, schedule: .everyDays(3),
                   notes: String(localized: "Usually 2–3 times a week.")),
        Medication(id: "salicylic.ointment", name: String(localized: "Salicylic acid ointment"), kind: .ointment, category: .tarAndKeratolytic, schedule: .daily(1),
                   notes: String(localized: "Softens thick scale before other treatments.")),
        Medication(id: "emollient", name: String(localized: "Emollient / moisturiser"), kind: .cream, category: .emollient, schedule: .asNeeded,
                   notes: String(localized: "Works best right after a shower or bath.")),
    ]

    // MARK: - Tablets

    private static let orals: [Medication] = [
        Medication(id: "methotrexate", name: String(localized: "Methotrexate"), kind: .pill, category: .conventionalOral, schedule: .weekly,
                   notes: String(localized: "Once a WEEK, not daily. Usually with folic acid on another day.")),
        Medication(id: "folic.acid", name: String(localized: "Folic acid (with methotrexate)"), kind: .pill, category: .conventionalOral, schedule: .weekly,
                   notes: String(localized: "Not on the methotrexate day. Some people take it daily — follow your doctor.")),
        Medication(id: "ciclosporin", name: String(localized: "Ciclosporin (cyclosporine)"), kind: .pill, category: .conventionalOral, schedule: .daily(2),
                   notes: String(localized: "Usually short-term, with blood pressure and kidney checks.")),
        Medication(id: "acitretin", name: String(localized: "Acitretin"), kind: .pill, category: .conventionalOral, schedule: .daily(1),
                   notes: String(localized: "Take with food. Pregnancy must be avoided during and for years after — ask your doctor.")),
        Medication(id: "dimethyl.fumarate", name: String(localized: "Dimethyl fumarate (Skilarence)"), kind: .pill, category: .conventionalOral, schedule: .daily(1),
                   notes: String(localized: "Dose is increased slowly. Take with food.")),
        Medication(id: "apremilast", name: String(localized: "Apremilast (Otezla)"), kind: .pill, category: .targetedOral, schedule: .daily(2),
                   notes: String(localized: "Dose is increased over the first days (starter pack).")),
        Medication(id: "deucravacitinib", name: String(localized: "Deucravacitinib (Sotyktu)"), kind: .pill, category: .targetedOral, schedule: .daily(1)),
        Medication(id: "icotrokinra", name: String(localized: "Icotrokinra (Icotyde)"), kind: .pill, category: .targetedOral, schedule: .daily(1),
                   notes: String(localized: "Take on an empty stomach.")),
    ]

    // MARK: - Biologics (maintenance interval; starting doses differ)

    private static let biologics: [Medication] = [
        Medication(id: "adalimumab", name: String(localized: "Adalimumab (Humira and biosimilars)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(2),
                   notes: String(localized: "Higher first dose, then every 2 weeks.")),
        Medication(id: "etanercept", name: String(localized: "Etanercept (Enbrel and biosimilars)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(1),
                   notes: String(localized: "Some people start twice a week.")),
        Medication(id: "infliximab", name: String(localized: "Infliximab"), kind: .biologic, category: .biologic, schedule: .everyWeeks(8),
                   notes: String(localized: "Infusion in clinic. Starting doses at weeks 0, 2 and 6.")),
        Medication(id: "ustekinumab", name: String(localized: "Ustekinumab (Stelara and biosimilars)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(12),
                   notes: String(localized: "Starting doses at weeks 0 and 4.")),
        Medication(id: "secukinumab", name: String(localized: "Secukinumab (Cosentyx)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(4),
                   notes: String(localized: "Weekly for the first 5 weeks.")),
        Medication(id: "ixekizumab", name: String(localized: "Ixekizumab (Taltz)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(4),
                   notes: String(localized: "Every 2 weeks until week 12.")),
        Medication(id: "brodalumab", name: String(localized: "Brodalumab (Siliq, Kyntheum)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(2),
                   notes: String(localized: "Weekly at weeks 0, 1 and 2.")),
        Medication(id: "bimekizumab", name: String(localized: "Bimekizumab (Bimzelx)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(8),
                   notes: String(localized: "Every 4 weeks until week 16.")),
        Medication(id: "guselkumab", name: String(localized: "Guselkumab (Tremfya)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(8),
                   notes: String(localized: "Starting doses at weeks 0 and 4.")),
        Medication(id: "risankizumab", name: String(localized: "Risankizumab (Skyrizi)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(12),
                   notes: String(localized: "Starting doses at weeks 0 and 4.")),
        Medication(id: "tildrakizumab", name: String(localized: "Tildrakizumab (Ilumya, Ilumetri)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(12),
                   notes: String(localized: "Starting doses at weeks 0 and 4.")),
        Medication(id: "spesolimab", name: String(localized: "Spesolimab (Spevigo)"), kind: .biologic, category: .biologic, schedule: .everyWeeks(4),
                   notes: String(localized: "For generalized pustular psoriasis.")),
    ]

    // MARK: - Phototherapy

    private static let phototherapy: [Medication] = [
        Medication(id: "nbuvb", name: String(localized: "Narrowband UVB"), kind: .phototherapy, category: .phototherapy, schedule: .everyDays(2),
                   notes: String(localized: "Usually 2–3 sessions a week; a course is about 20–30 sessions.")),
    ]
}
