import Foundation

// Stable domain types. Raw values are persisted as strings:
// add new cases freely, but never rename or remove existing raw values.
// `nonisolated` so the types can be used from pure logic and SwiftData off the main actor.

// MARK: - Psoriasis type

nonisolated enum PsoriasisType: String, Codable, CaseIterable, Identifiable, Sendable {
    case plaque, guttate, inverse, pustular, palmoplantar, nail, scalp, genital

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plaque: "Plaque"
        case .guttate: "Guttate"
        case .inverse: "Inverse (skin folds)"
        case .pustular: "Pustular"
        case .palmoplantar: "Palms & soles"
        case .nail: "Nail"
        case .scalp: "Scalp"
        case .genital: "Genital"
        }
    }

    var systemImage: String {
        switch self {
        case .plaque: "circle.hexagongrid"
        case .guttate: "circle.dotted"
        case .inverse: "arrow.left.and.right"
        case .pustular: "smallcircle.filled.circle"
        case .palmoplantar: "hand.raised"
        case .nail: "hand.point.up"
        case .scalp: "comb"
        case .genital: "lock"
        }
    }
}

// MARK: - Trigger

nonisolated enum Trigger: String, Codable, CaseIterable, Identifiable, Sendable {
    case stress, alcohol, smoking, infection, skinInjury, newMedication, sunburn, coldDry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stress: "Stress"
        case .alcohol: "Alcohol"
        case .smoking: "Smoking"
        case .infection: "Sick / sore throat"
        case .skinInjury: "Skin injury"
        case .newMedication: "New medication"
        case .sunburn: "Sunburn"
        case .coldDry: "Cold / dry air"
        }
    }

    var systemImage: String {
        switch self {
        case .stress: "brain.head.profile"
        case .alcohol: "wineglass"
        case .smoking: "smoke"
        case .infection: "facemask"
        case .skinInjury: "bandage"
        case .newMedication: "pills"
        case .sunburn: "sun.max"
        case .coldDry: "snowflake"
        }
    }
}

// MARK: - Treatment kind

nonisolated enum TreatmentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case cream, ointment, shampoo, foam, pill, biologic, phototherapy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cream: "Cream"
        case .ointment: "Ointment"
        case .shampoo: "Shampoo"
        case .foam: "Foam"
        case .pill: "Tablets"
        case .biologic: "Biologic"
        case .phototherapy: "Phototherapy"
        }
    }

    var systemImage: String {
        switch self {
        case .cream, .ointment: "hand.point.up.left"
        case .shampoo: "shower"
        case .foam: "bubbles.and.sparkles"
        case .pill: "pills"
        case .biologic: "syringe"
        case .phototherapy: "sun.max"
        }
    }

    /// Topicals can have a steroid potency class.
    var isTopical: Bool {
        switch self {
        case .cream, .ointment, .shampoo, .foam: true
        case .pill, .biologic, .phototherapy: false
        }
    }
}

// MARK: - Steroid potency class (US I–VII, I is the strongest)

nonisolated enum SteroidClass: String, Codable, CaseIterable, Identifiable, Sendable {
    case class1, class2, class3, class4, class5, class6, class7

    var id: String { rawValue }

    /// 1…7, where 1 is super-potent.
    var number: Int {
        switch self {
        case .class1: 1
        case .class2: 2
        case .class3: 3
        case .class4: 4
        case .class5: 5
        case .class6: 6
        case .class7: 7
        }
    }

    var title: String {
        switch self {
        case .class1: "Class I · super-potent"
        case .class2: "Class II · high potency"
        case .class3: "Class III · upper-mid potency"
        case .class4: "Class IV · medium potency"
        case .class5: "Class V · lower-mid potency"
        case .class6: "Class VI · low potency"
        case .class7: "Class VII · least potent"
        }
    }

    var systemImage: String {
        switch self {
        case .class1, .class2: "gauge.with.dots.needle.100percent"
        case .class3, .class4: "gauge.with.dots.needle.67percent"
        case .class5: "gauge.with.dots.needle.33percent"
        case .class6, .class7: "gauge.with.dots.needle.0percent"
        }
    }
}

// MARK: - Schedule kind

nonisolated enum ScheduleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// N times a day.
    case timesPerDay
    /// Once a week on a chosen weekday.
    case weekly
    /// Every N days.
    case everyNDays
    /// Every N weeks (biologics: q2w, q4w, q8w, q12w).
    case everyNWeeks
    /// No fixed schedule, e.g. emollient after a shower.
    case asNeeded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timesPerDay: "Times a day"
        case .weekly: "Once a week"
        case .everyNDays: "Every few days"
        case .everyNWeeks: "Every few weeks"
        case .asNeeded: "As needed"
        }
    }

    var systemImage: String {
        switch self {
        case .timesPerDay: "clock"
        case .weekly: "calendar"
        case .everyNDays: "calendar.badge.clock"
        case .everyNWeeks: "calendar.circle"
        case .asNeeded: "hand.tap"
        }
    }
}

// MARK: - Questionnaire kind

nonisolated enum QuestionnaireKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case dlqi, pest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dlqi: "Quality of life (DLQI)"
        case .pest: "Joint screening (PEST)"
        }
    }

    var systemImage: String {
        switch self {
        case .dlqi: "heart.text.square"
        case .pest: "figure.walk"
        }
    }
}

// MARK: - Dose status

nonisolated enum DoseStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case done, skipped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .done: "Done"
        case .skipped: "Skipped"
        }
    }

    var systemImage: String {
        switch self {
        case .done: "checkmark.circle.fill"
        case .skipped: "xmark.circle"
        }
    }
}
