import SwiftUI

// MARK: - Onboarding answers

enum Condition: String, CaseIterable, Identifiable {
    case psoriasis, eczema, seborrheic, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .psoriasis: "Psoriasis"
        case .eczema: "Atopic dermatitis (eczema)"
        case .seborrheic: "Seborrheic dermatitis"
        case .other: "Other / not diagnosed yet"
        }
    }

    var subtitle: String {
        switch self {
        case .psoriasis: "Plaques, scaling, often on elbows, knees, scalp"
        case .eczema: "Dry, itchy patches that come and go"
        case .seborrheic: "Flaking on scalp, face or chest"
        case .other: "That's okay — we'll keep it flexible"
        }
    }

    var systemImage: String {
        switch self {
        case .psoriasis: "circle.hexagongrid"
        case .eczema: "drop"
        case .seborrheic: "leaf"
        case .other: "questionmark.circle"
        }
    }
}

enum ProfileKind: String, CaseIterable, Identifiable {
    case myself, child
    var id: String { rawValue }
}

enum Goal: String, CaseIterable, Identifiable {
    case triggers, treatment, doctor, sleep, journal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .triggers: "Find my triggers"
        case .treatment: "Check my treatment"
        case .doctor: "Prepare for my doctor"
        case .sleep: "Itch less, sleep better"
        case .journal: "Just keep a diary"
        }
    }

    var systemImage: String {
        switch self {
        case .triggers: "magnifyingglass"
        case .treatment: "cross.vial"
        case .doctor: "stethoscope"
        case .sleep: "moon.zzz"
        case .journal: "book.closed"
        }
    }
}

enum AppMode: String, CaseIterable, Identifiable {
    case calm, flare
    var id: String { rawValue }
    var title: String { self == .calm ? "Calm" : "Flare" }
}

// MARK: - Tracking data

struct DayValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct Treatment: Identifiable {
    let id = UUID()
    let name: String
    let kind: TreatmentKind
    let zones: [String]
    let frequency: String
    let started: Date
    var fingertipUnits: Double?
    var nextDoseInDays: Int?
}

struct TreatmentReminder: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    var isDone: Bool = false
}

enum InjectionSite: String, CaseIterable, Identifiable {
    case abdomenLeft, abdomenRight, thighLeft, thighRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .abdomenLeft: "Abdomen · left"
        case .abdomenRight: "Abdomen · right"
        case .thighLeft: "Thigh · left"
        case .thighRight: "Thigh · right"
        }
    }
}

struct Insight: Identifiable {
    let id = UUID()
    let text: String
    let evidence: String
    let systemImage: String
    /// 0...1 — shown as a soft confidence meter.
    let confidence: Double
}

struct Experiment {
    let title: String
    let day: Int
    let totalDays: Int
    let note: String
}

struct PhotoEntry: Identifiable {
    let id = UUID()
    let date: Date
    let seed: Int
    /// 0 = very inflamed, 1 = calm. Drives the abstract placeholder.
    let calmness: Double
}

struct TreatmentMarker: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
}

struct PhotoZone: Identifiable {
    let id: String
    let name: String
    var photos: [PhotoEntry]
    var treatmentMarkers: [TreatmentMarker]
}
