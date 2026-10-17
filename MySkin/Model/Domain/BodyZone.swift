import SwiftUI

// MARK: - Body map

enum BodySide: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var title: String {
        self == .front
            ? String(localized: "side.front", defaultValue: "Front", comment: "Front of the body")
            : String(localized: "side.back", defaultValue: "Back", comment: "Back of the body")
    }
}

/// Body regions used by the severity index (PASI weights: head 0.1, arms 0.2, trunk 0.3, legs 0.4).
nonisolated enum BodyRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case head, arms, trunk, legs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .head: String(localized: "Head & neck")
        case .arms: String(localized: "Arms")
        case .trunk: String(localized: "Trunk")
        case .legs: String(localized: "Legs")
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
    /// A quick zone that isn't drawn on the silhouette (the neck), so its area adds to its region.
    /// Other quick zones lie inside silhouette zones.
    var isStandalone: Bool = false

    static func == (lhs: BodyZone, rhs: BodyZone) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let designSize = CGSize(width: 200, height: 460)

    /// Zones for one side of the silhouette. Left/right are from the person's perspective.
    static func zones(for side: BodySide) -> [BodyZone] {
        let prefix = side.rawValue
        // Image-left is the person's right in front view, and their left in back view.
        let imageLeft = side == .front ? "Right" : "Left"
        let imageRight = side == .front ? "Left" : "Right"

        /// `left`/`right` are the person's left and right zone names.
        func pair(_ key: String, left: String, right: String, _ rect: CGRect, _ kind: ZoneShapeKind, _ area: Double, _ region: BodyRegion, special: Bool = false) -> [BodyZone] {
            let mirrored = CGRect(x: designSize.width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
            func name(_ side: String) -> String { side == "Left" ? left : right }
            return [
                BodyZone(id: "\(prefix).\(key).\(imageLeft.lowercased())", name: name(imageLeft), rect: rect, kind: kind, area: area, region: region, isSpecialSite: special),
                BodyZone(id: "\(prefix).\(key).\(imageRight.lowercased())", name: name(imageRight), rect: mirrored, kind: kind, area: area, region: region, isSpecialSite: special),
            ]
        }

        var zones: [BodyZone] = [
            // The face is a special site; the back of the head is covered by `quick.scalp`.
            BodyZone(id: "\(prefix).head", name: side == .front ? String(localized: "Face") : String(localized: "Back of head"), rect: CGRect(x: 73, y: 0, width: 54, height: 50), kind: .ellipse, area: 4.5, region: .head, isSpecialSite: side == .front),
            // The neck is too small to tap on the silhouette: it's the quick zone `quick.neck`.
            BodyZone(id: "\(prefix).torso.upper", name: side == .front ? String(localized: "Chest") : String(localized: "Upper back"), rect: CGRect(x: 61, y: 76, width: 78, height: 74), kind: .rounded, area: 9, region: .trunk),
            BodyZone(id: "\(prefix).torso.lower", name: side == .front ? String(localized: "Abdomen") : String(localized: "Lower back"), rect: CGRect(x: 61, y: 150, width: 78, height: 62), kind: .rounded, area: 9, region: .trunk),
            // PASI counts the buttocks with the lower limbs.
            BodyZone(id: "\(prefix).pelvis", name: side == .front ? String(localized: "Hips") : String(localized: "Buttocks"), rect: CGRect(x: 54, y: 212, width: 92, height: 38), kind: .rounded, area: side == .front ? 1 : 2.5, region: .legs),
        ]
        zones += pair("upperarm", left: String(localized: "Left upper arm"), right: String(localized: "Right upper arm"), CGRect(x: 36, y: 84, width: 25, height: 70), .capsule, 1.8, .arms)
        zones += pair("elbow", left: String(localized: "Left elbow"), right: String(localized: "Right elbow"), CGRect(x: 30, y: 154, width: 27, height: 26), .ellipse, 0.4, .arms)
        zones += pair("forearm", left: String(localized: "Left forearm"), right: String(localized: "Right forearm"), CGRect(x: 20, y: 180, width: 32, height: 48), .capsule, 1.3, .arms)
        // Front view shows the palms (a special site, spec §2.2); back view — the back of the hands.
        zones += pair("hand", left: side == .front ? String(localized: "Left palm") : String(localized: "Left hand"),
                      right: side == .front ? String(localized: "Right palm") : String(localized: "Right hand"), CGRect(x: 2, y: 228, width: 36, height: 42), .ellipse, 1.0, .arms, special: side == .front)
        zones += pair("thigh", left: String(localized: "Left thigh"), right: String(localized: "Right thigh"), CGRect(x: 54, y: 250, width: 45, height: 70), .capsule, 4.5, .legs)
        zones += pair("knee", left: String(localized: "Left knee"), right: String(localized: "Right knee"), CGRect(x: 63, y: 320, width: 30, height: 28), .ellipse, 0.8, .legs)
        zones += pair("shin", left: String(localized: "Left shin"), right: String(localized: "Right shin"), CGRect(x: 63, y: 348, width: 29, height: 80), .capsule, 3, .legs)
        zones += pair("foot", left: String(localized: "Left foot"), right: String(localized: "Right foot"), CGRect(x: 59, y: 428, width: 33, height: 32), .capsule, 0.7, .legs)
        return zones
    }

    /// Areas that are hard to show or tap on a silhouette. Face and palms are on the silhouette itself.
    static let quickZones: [BodyZone] = [
        BodyZone(id: "quick.scalp", name: String(localized: "Scalp"), rect: .zero, kind: .rounded, area: 1.0, region: .head, isSpecialSite: true),
        // Front and back of the neck together (1 % each).
        BodyZone(id: "quick.neck", name: String(localized: "Neck"), rect: .zero, kind: .rounded, area: 2.0, region: .head, isStandalone: true),
        BodyZone(id: "quick.nails", name: String(localized: "Nails"), rect: .zero, kind: .rounded, area: 0.1, region: .arms, isSpecialSite: true),
        BodyZone(id: "quick.soles", name: String(localized: "Soles"), rect: .zero, kind: .rounded, area: 1.0, region: .legs, isSpecialSite: true),
        BodyZone(id: "quick.folds", name: String(localized: "Skin folds"), rect: .zero, kind: .rounded, area: 2.0, region: .trunk, isSpecialSite: true),
        BodyZone(id: "quick.genitals", name: String(localized: "Genitals"), rect: .zero, kind: .rounded, area: 1.0, region: .trunk, isSpecialSite: true),
    ]

    /// Zones are built once and reused on every render.
    static let frontZones = zones(for: .front)
    static let backZones = zones(for: .back)
    static func cached(for side: BodySide) -> [BodyZone] { side == .front ? frontZones : backZones }

    /// Zones of the current map: the silhouette and the quick zones.
    static let all: [BodyZone] = frontZones + backZones + quickZones

    /// Zones no longer on the map. Stored data still uses their ids (never reuse them), so their names
    /// resolve for history and photos; `canonicalID` moves their assessments to the zone that replaced them.
    static let retired: [BodyZone] = [
        BodyZone(id: "front.neck", name: String(localized: "Neck"), rect: .zero, kind: .rounded, area: 1, region: .head),
        BodyZone(id: "back.neck", name: String(localized: "Back of neck"), rect: .zero, kind: .rounded, area: 1, region: .head),
        BodyZone(id: "quick.face", name: String(localized: "Face"), rect: .zero, kind: .rounded, area: 3.0, region: .head, isSpecialSite: true),
        // Left or right is unknown, so old palm ratings have no zone on the current map.
        BodyZone(id: "quick.palms", name: String(localized: "Palms"), rect: .zero, kind: .rounded, area: 1.0, region: .arms, isSpecialSite: true),
    ]

    /// Zone of the current map that a stored id belongs to: retired ids move to their replacement.
    nonisolated static func canonicalID(_ id: String) -> String {
        switch id {
        case "front.neck", "back.neck": "quick.neck"
        case "quick.face": "front.head"
        default: id
        }
    }

    /// Looks up a zone of the current map by its stored id.
    static func zone(id: String) -> BodyZone? { all.first { $0.id == id } }

    /// Like `zone(id:)`, but also finds retired zones — for names in history and photos.
    static func named(id: String) -> BodyZone? { zone(id: id) ?? retired.first { $0.id == id } }
}
