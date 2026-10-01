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

// MARK: - Body map

enum BodySide: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var title: String { self == .front ? "Front" : "Back" }
}

enum ZoneShapeKind {
    case ellipse, capsule, rounded

    var shape: AnyShape {
        switch self {
        case .ellipse: AnyShape(Ellipse())
        case .capsule: AnyShape(Capsule())
        case .rounded: AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

struct BodyZone: Identifiable, Hashable {
    let id: String
    let name: String
    /// Frame in a 200 × 440 design space.
    let rect: CGRect
    let kind: ZoneShapeKind
    /// Approximate share of total body surface, in percent.
    let area: Double

    static func == (lhs: BodyZone, rhs: BodyZone) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let designSize = CGSize(width: 200, height: 440)

    /// Zones for one side of the silhouette. Left/right are from the person's perspective.
    static func zones(for side: BodySide) -> [BodyZone] {
        let prefix = side.rawValue
        // Image-left is the person's right in front view, and their left in back view.
        let imageLeft = side == .front ? "Right" : "Left"
        let imageRight = side == .front ? "Left" : "Right"

        func pair(_ key: String, _ name: String, _ rect: CGRect, _ kind: ZoneShapeKind, _ area: Double) -> [BodyZone] {
            let mirrored = CGRect(x: designSize.width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
            return [
                BodyZone(id: "\(prefix).\(key).\(imageLeft.lowercased())", name: "\(imageLeft) \(name)", rect: rect, kind: kind, area: area),
                BodyZone(id: "\(prefix).\(key).\(imageRight.lowercased())", name: "\(imageRight) \(name)", rect: mirrored, kind: kind, area: area),
            ]
        }

        var zones: [BodyZone] = [
            BodyZone(id: "\(prefix).head", name: side == .front ? "Face" : "Back of head", rect: CGRect(x: 78, y: 6, width: 44, height: 54), kind: .ellipse, area: 4.5),
            BodyZone(id: "\(prefix).neck", name: "Neck", rect: CGRect(x: 90, y: 56, width: 20, height: 20), kind: .rounded, area: 1),
            BodyZone(id: "\(prefix).torso.upper", name: side == .front ? "Chest" : "Upper back", rect: CGRect(x: 62, y: 74, width: 76, height: 68), kind: .rounded, area: 9),
            BodyZone(id: "\(prefix).torso.lower", name: side == .front ? "Abdomen" : "Lower back", rect: CGRect(x: 65, y: 144, width: 70, height: 56), kind: .rounded, area: 9),
            BodyZone(id: "\(prefix).pelvis", name: side == .front ? "Hips" : "Buttocks", rect: CGRect(x: 63, y: 202, width: 74, height: 34), kind: .rounded, area: side == .front ? 1 : 2.5),
        ]
        zones += pair("upperarm", "upper arm", CGRect(x: 38, y: 78, width: 22, height: 70), .capsule, 1.8)
        zones += pair("elbow", "elbow", CGRect(x: 32, y: 146, width: 24, height: 26), .ellipse, 0.4)
        zones += pair("forearm", "forearm", CGRect(x: 26, y: 170, width: 24, height: 56), .capsule, 1.3)
        zones += pair("hand", "hand", CGRect(x: 20, y: 226, width: 26, height: 34), .ellipse, 1.0)
        zones += pair("thigh", "thigh", CGRect(x: 66, y: 238, width: 32, height: 80), .capsule, 4.5)
        zones += pair("knee", "knee", CGRect(x: 69, y: 318, width: 26, height: 26), .ellipse, 0.8)
        zones += pair("shin", "shin", CGRect(x: 71, y: 344, width: 22, height: 62), .capsule, 3)
        zones += pair("foot", "foot", CGRect(x: 66, y: 406, width: 30, height: 22), .capsule, 0.7)
        return zones
    }

    /// Quick zones that are hard to show on a silhouette.
    static let quickZones: [BodyZone] = [
        BodyZone(id: "quick.scalp", name: "Scalp", rect: .zero, kind: .rounded, area: 1.0),
        BodyZone(id: "quick.nails", name: "Nails", rect: .zero, kind: .rounded, area: 0.1),
        BodyZone(id: "quick.palms", name: "Palms", rect: .zero, kind: .rounded, area: 1.0),
        BodyZone(id: "quick.soles", name: "Soles", rect: .zero, kind: .rounded, area: 1.0),
    ]

    /// Zones are built once and reused on every render.
    static let frontZones = zones(for: .front)
    static let backZones = zones(for: .back)
    static func cached(for side: BodySide) -> [BodyZone] { side == .front ? frontZones : backZones }

    static let all: [BodyZone] = frontZones + backZones + quickZones
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
