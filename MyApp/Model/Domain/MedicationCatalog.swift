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
        case .topicalSteroid: "Steroid creams & ointments"
        case .steroidVitaminD: "Steroid + vitamin D"
        case .vitaminD: "Vitamin D creams"
        case .nonSteroidalTopical: "Non-steroid creams"
        case .calcineurinInhibitor: "Calcineurin inhibitors"
        case .tarAndKeratolytic: "Tar & scale softeners"
        case .emollient: "Moisturisers"
        case .conventionalOral: "Tablets"
        case .targetedOral: "Targeted tablets"
        case .biologic: "Biologics"
        case .phototherapy: "Phototherapy"
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
        Medication(id: "clobetasol.ointment", name: "Clobetasol propionate 0.05% ointment", kind: .ointment, category: .topicalSteroid, steroidClass: .class1, schedule: .daily(2),
                   notes: "Very strong. Usually short courses; not for the face or skin folds unless your doctor says so."),
        Medication(id: "clobetasol.shampoo", name: "Clobetasol propionate 0.05% shampoo", kind: .shampoo, category: .topicalSteroid, steroidClass: .class1, schedule: .daily(1),
                   notes: "Apply to dry scalp, leave for 15 minutes, then rinse."),
        Medication(id: "betamethasone.dipropionate.ointment", name: "Betamethasone dipropionate 0.05% ointment", kind: .ointment, category: .topicalSteroid, steroidClass: .class2, schedule: .daily(1)),
        Medication(id: "fluocinonide.cream", name: "Fluocinonide 0.05% cream", kind: .cream, category: .topicalSteroid, steroidClass: .class2, schedule: .daily(2)),
        Medication(id: "mometasone.cream", name: "Mometasone furoate 0.1% cream", kind: .cream, category: .topicalSteroid, steroidClass: .class4, schedule: .daily(1)),
        Medication(id: "triamcinolone.cream", name: "Triamcinolone acetonide 0.1% cream", kind: .cream, category: .topicalSteroid, steroidClass: .class4, schedule: .daily(2)),
        Medication(id: "betamethasone.valerate.cream", name: "Betamethasone valerate 0.1% cream", kind: .cream, category: .topicalSteroid, steroidClass: .class5, schedule: .daily(2)),
        Medication(id: "desonide.cream", name: "Desonide 0.05% cream", kind: .cream, category: .topicalSteroid, steroidClass: .class6, schedule: .daily(2),
                   notes: "Mild; often used on the face and skin folds."),
        Medication(id: "hydrocortisone.cream", name: "Hydrocortisone 1% cream", kind: .cream, category: .topicalSteroid, steroidClass: .class7, schedule: .daily(2)),
        Medication(id: "calcipotriol.betamethasone", name: "Calcipotriol + betamethasone (Daivobet, Taclonex)", kind: .ointment, category: .steroidVitaminD, steroidClass: .class2, schedule: .daily(1)),

        Medication(id: "calcipotriol.cream", name: "Calcipotriol (calcipotriene) 0.005% cream", kind: .cream, category: .vitaminD, schedule: .daily(2)),
        Medication(id: "calcitriol.ointment", name: "Calcitriol ointment", kind: .ointment, category: .vitaminD, schedule: .daily(2)),
        Medication(id: "roflumilast.cream", name: "Roflumilast 0.3% cream (Zoryve)", kind: .cream, category: .nonSteroidalTopical, schedule: .daily(1)),
        Medication(id: "tapinarof.cream", name: "Tapinarof 1% cream (Vtama)", kind: .cream, category: .nonSteroidalTopical, schedule: .daily(1)),
        Medication(id: "tacrolimus.ointment", name: "Tacrolimus 0.1% ointment", kind: .ointment, category: .calcineurinInhibitor, schedule: .daily(2),
                   notes: "Often used on the face and skin folds."),
        Medication(id: "coaltar.shampoo", name: "Coal tar shampoo", kind: .shampoo, category: .tarAndKeratolytic, schedule: .everyDays(3),
                   notes: "Usually 2–3 times a week."),
        Medication(id: "salicylic.ointment", name: "Salicylic acid ointment", kind: .ointment, category: .tarAndKeratolytic, schedule: .daily(1),
                   notes: "Softens thick scale before other treatments."),
        Medication(id: "emollient", name: "Emollient / moisturiser", kind: .cream, category: .emollient, schedule: .asNeeded,
                   notes: "Works best right after a shower or bath."),
    ]

    // MARK: - Tablets

    private static let orals: [Medication] = [
        Medication(id: "methotrexate", name: "Methotrexate", kind: .pill, category: .conventionalOral, schedule: .weekly,
                   notes: "Once a WEEK, not daily. Usually with folic acid on another day."),
        Medication(id: "folic.acid", name: "Folic acid (with methotrexate)", kind: .pill, category: .conventionalOral, schedule: .weekly,
                   notes: "Not on the methotrexate day. Some people take it daily — follow your doctor."),
        Medication(id: "ciclosporin", name: "Ciclosporin (cyclosporine)", kind: .pill, category: .conventionalOral, schedule: .daily(2),
                   notes: "Usually short-term, with blood pressure and kidney checks."),
        Medication(id: "acitretin", name: "Acitretin", kind: .pill, category: .conventionalOral, schedule: .daily(1),
                   notes: "Take with food. Pregnancy must be avoided during and for years after — ask your doctor."),
        Medication(id: "dimethyl.fumarate", name: "Dimethyl fumarate (Skilarence)", kind: .pill, category: .conventionalOral, schedule: .daily(1),
                   notes: "Dose is increased slowly. Take with food."),
        Medication(id: "apremilast", name: "Apremilast (Otezla)", kind: .pill, category: .targetedOral, schedule: .daily(2),
                   notes: "Dose is increased over the first days (starter pack)."),
        Medication(id: "deucravacitinib", name: "Deucravacitinib (Sotyktu)", kind: .pill, category: .targetedOral, schedule: .daily(1)),
        Medication(id: "icotrokinra", name: "Icotrokinra (Icotyde)", kind: .pill, category: .targetedOral, schedule: .daily(1),
                   notes: "Take on an empty stomach."),
    ]

    // MARK: - Biologics (maintenance interval; starting doses differ)

    private static let biologics: [Medication] = [
        Medication(id: "adalimumab", name: "Adalimumab (Humira and biosimilars)", kind: .biologic, category: .biologic, schedule: .everyWeeks(2),
                   notes: "Higher first dose, then every 2 weeks."),
        Medication(id: "etanercept", name: "Etanercept (Enbrel and biosimilars)", kind: .biologic, category: .biologic, schedule: .everyWeeks(1),
                   notes: "Some people start twice a week."),
        Medication(id: "infliximab", name: "Infliximab", kind: .biologic, category: .biologic, schedule: .everyWeeks(8),
                   notes: "Infusion in clinic. Starting doses at weeks 0, 2 and 6."),
        Medication(id: "ustekinumab", name: "Ustekinumab (Stelara and biosimilars)", kind: .biologic, category: .biologic, schedule: .everyWeeks(12),
                   notes: "Starting doses at weeks 0 and 4."),
        Medication(id: "secukinumab", name: "Secukinumab (Cosentyx)", kind: .biologic, category: .biologic, schedule: .everyWeeks(4),
                   notes: "Weekly for the first 5 weeks."),
        Medication(id: "ixekizumab", name: "Ixekizumab (Taltz)", kind: .biologic, category: .biologic, schedule: .everyWeeks(4),
                   notes: "Every 2 weeks until week 12."),
        Medication(id: "brodalumab", name: "Brodalumab (Siliq, Kyntheum)", kind: .biologic, category: .biologic, schedule: .everyWeeks(2),
                   notes: "Weekly at weeks 0, 1 and 2."),
        Medication(id: "bimekizumab", name: "Bimekizumab (Bimzelx)", kind: .biologic, category: .biologic, schedule: .everyWeeks(8),
                   notes: "Every 4 weeks until week 16."),
        Medication(id: "guselkumab", name: "Guselkumab (Tremfya)", kind: .biologic, category: .biologic, schedule: .everyWeeks(8),
                   notes: "Starting doses at weeks 0 and 4."),
        Medication(id: "risankizumab", name: "Risankizumab (Skyrizi)", kind: .biologic, category: .biologic, schedule: .everyWeeks(12),
                   notes: "Starting doses at weeks 0 and 4."),
        Medication(id: "tildrakizumab", name: "Tildrakizumab (Ilumya, Ilumetri)", kind: .biologic, category: .biologic, schedule: .everyWeeks(12),
                   notes: "Starting doses at weeks 0 and 4."),
        Medication(id: "spesolimab", name: "Spesolimab (Spevigo)", kind: .biologic, category: .biologic, schedule: .everyWeeks(4),
                   notes: "For generalized pustular psoriasis."),
    ]

    // MARK: - Phototherapy

    private static let phototherapy: [Medication] = [
        Medication(id: "nbuvb", name: "Narrowband UVB", kind: .phototherapy, category: .phototherapy, schedule: .everyDays(2),
                   notes: "Usually 2–3 sessions a week; a course is about 20–30 sessions."),
    ]
}
