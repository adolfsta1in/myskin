import SwiftUI

// MARK: - Body map

enum BodySide: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var title: String { self == .front ? "Front" : "Back" }
}

/// Body regions used by the severity index (PASI weights: head 0.1, arms 0.2, trunk 0.3, legs 0.4).
nonisolated enum BodyRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case head, arms, trunk, legs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .head: "Head & neck"
        case .arms: "Arms"
        case .trunk: "Trunk"
        case .legs: "Legs"
        }
    }
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
    /// Stable id stored in the database, e.g. `front.elbow.left`. Never rename.
    let id: String
    let name: String
    /// Frame in a 200 × 460 design space, matched to the `BodyFront`/`BodyBack` illustrations.
    let rect: CGRect
    let kind: ZoneShapeKind
    /// Approximate share of total body surface, in percent.
    let area: Double
    /// Region for the severity index.
    let region: BodyRegion
    /// Special sites raise severity even when the affected area is small (spec §2.2).
    var isSpecialSite: Bool = false

    static func == (lhs: BodyZone, rhs: BodyZone) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let designSize = CGSize(width: 200, height: 460)

    /// Zones for one side of the silhouette. Left/right are from the person's perspective.
    static func zones(for side: BodySide) -> [BodyZone] {
        let prefix = side.rawValue
        // Image-left is the person's right in front view, and their left in back view.
        let imageLeft = side == .front ? "Right" : "Left"
        let imageRight = side == .front ? "Left" : "Right"

        func pair(_ key: String, _ name: String, _ rect: CGRect, _ kind: ZoneShapeKind, _ area: Double, _ region: BodyRegion) -> [BodyZone] {
            let mirrored = CGRect(x: designSize.width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
            return [
                BodyZone(id: "\(prefix).\(key).\(imageLeft.lowercased())", name: "\(imageLeft) \(name)", rect: rect, kind: kind, area: area, region: region),
                BodyZone(id: "\(prefix).\(key).\(imageRight.lowercased())", name: "\(imageRight) \(name)", rect: mirrored, kind: kind, area: area, region: region),
            ]
        }

        var zones: [BodyZone] = [
            // The face is a special site; the back of the head is covered by `quick.scalp`.
            BodyZone(id: "\(prefix).head", name: side == .front ? "Face" : "Back of head", rect: CGRect(x: 73, y: 0, width: 54, height: 50), kind: .ellipse, area: 4.5, region: .head, isSpecialSite: side == .front),
            BodyZone(id: "\(prefix).neck", name: "Neck", rect: CGRect(x: 83, y: 50, width: 34, height: 26), kind: .rounded, area: 1, region: .head),
            BodyZone(id: "\(prefix).torso.upper", name: side == .front ? "Chest" : "Upper back", rect: CGRect(x: 61, y: 76, width: 78, height: 74), kind: .rounded, area: 9, region: .trunk),
            BodyZone(id: "\(prefix).torso.lower", name: side == .front ? "Abdomen" : "Lower back", rect: CGRect(x: 61, y: 150, width: 78, height: 62), kind: .rounded, area: 9, region: .trunk),
            // PASI counts the buttocks with the lower limbs.
            BodyZone(id: "\(prefix).pelvis", name: side == .front ? "Hips" : "Buttocks", rect: CGRect(x: 54, y: 212, width: 92, height: 38), kind: .rounded, area: side == .front ? 1 : 2.5, region: .legs),
        ]
        zones += pair("upperarm", "upper arm", CGRect(x: 36, y: 84, width: 25, height: 70), .capsule, 1.8, .arms)
        zones += pair("elbow", "elbow", CGRect(x: 30, y: 154, width: 27, height: 26), .ellipse, 0.4, .arms)
        zones += pair("forearm", "forearm", CGRect(x: 20, y: 180, width: 32, height: 48), .capsule, 1.3, .arms)
        zones += pair("hand", "hand", CGRect(x: 2, y: 228, width: 36, height: 42), .ellipse, 1.0, .arms)
        zones += pair("thigh", "thigh", CGRect(x: 54, y: 250, width: 45, height: 70), .capsule, 4.5, .legs)
        zones += pair("knee", "knee", CGRect(x: 63, y: 320, width: 30, height: 28), .ellipse, 0.8, .legs)
        zones += pair("shin", "shin", CGRect(x: 63, y: 348, width: 29, height: 80), .capsule, 3, .legs)
        zones += pair("foot", "foot", CGRect(x: 59, y: 428, width: 33, height: 32), .capsule, 0.7, .legs)
        return zones
    }

    /// Special sites that are hard to show on a silhouette.
    static let quickZones: [BodyZone] = [
        BodyZone(id: "quick.scalp", name: "Scalp", rect: .zero, kind: .rounded, area: 1.0, region: .head, isSpecialSite: true),
        BodyZone(id: "quick.face", name: "Face", rect: .zero, kind: .rounded, area: 3.0, region: .head, isSpecialSite: true),
        BodyZone(id: "quick.nails", name: "Nails", rect: .zero, kind: .rounded, area: 0.1, region: .arms, isSpecialSite: true),
        BodyZone(id: "quick.palms", name: "Palms", rect: .zero, kind: .rounded, area: 1.0, region: .arms, isSpecialSite: true),
        BodyZone(id: "quick.soles", name: "Soles", rect: .zero, kind: .rounded, area: 1.0, region: .legs, isSpecialSite: true),
        BodyZone(id: "quick.folds", name: "Skin folds", rect: .zero, kind: .rounded, area: 2.0, region: .trunk, isSpecialSite: true),
        BodyZone(id: "quick.genitals", name: "Genitals", rect: .zero, kind: .rounded, area: 1.0, region: .trunk, isSpecialSite: true),
    ]

    /// Zones are built once and reused on every render.
    static let frontZones = zones(for: .front)
    static let backZones = zones(for: .back)
    static func cached(for side: BodySide) -> [BodyZone] { side == .front ? frontZones : backZones }

    static let all: [BodyZone] = frontZones + backZones + quickZones

    /// Looks up a zone by its stored id.
    static func zone(id: String) -> BodyZone? { all.first { $0.id == id } }
}
