import Foundation

// MARK: - Input

/// Value copy of one `ZoneAssessment`, so the calculator stays a pure function
/// that tests can call without a SwiftData container.
struct ZoneScore: Hashable, Sendable {
    let zoneID: String
    /// Affected area in palms (1 palm ≈ 1 % of body surface).
    var palms: Double
    /// Redness, thickness and scaling, each 0–4.
    var erythema: Int = 0
    var induration: Int = 0
    var scale: Int = 0

    /// A zone counts as affected if it has area or any visible sign.
    var isAffected: Bool { palms > 0 || erythema > 0 || induration > 0 || scale > 0 }
}

extension ZoneAssessment {
    var score: ZoneScore {
        ZoneScore(zoneID: zoneID, palms: palms, erythema: erythema, induration: induration, scale: scale)
    }
}

// MARK: - Output

/// Severity hint, not a diagnosis (spec §2.2).
nonisolated enum SeverityCategory: Int, Comparable, Sendable {
    case mild, moderate, severe

    var title: String {
        switch self {
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .severe: "Severe"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Computed, never stored (migration plan §1.5).
struct SeveritySnapshot: Equatable, Sendable {
    /// Affected body surface, 0–100 %.
    let bsa: Double
    /// Approximate self-PASI, 0–72. Shown as "severity index".
    let severityIndex: Double
    /// Affected special sites, in `BodyZone.all` order.
    let specialSiteIDs: [String]
    /// Category after the special-site / arthritis upgrade.
    let category: SeverityCategory
    /// Special site or suspected arthritis: "may be a reason to discuss systemic therapy".
    let isElevated: Bool

    static let empty = SeveritySnapshot(bsa: 0, severityIndex: 0, specialSiteIDs: [], category: .mild, isElevated: false)
}

// MARK: - Calculator

/// BSA, self-PASI and severity category (spec §2.2, research «rule of tens»).
enum SeverityCalculator {
    /// Thresholds in one place so they are easy to tune.
    enum Threshold {
        /// BSA below this is mild (AAD).
        static let mildBSA = 3.0
        /// BSA, index or DLQI above this is severe («rule of tens»).
        static let tens = 10.0
    }

    /// PASI region weights.
    static func weight(of region: BodyRegion) -> Double {
        switch region {
        case .head: 0.1
        case .arms: 0.2
        case .trunk: 0.3
        case .legs: 0.4
        }
    }

    /// Total area of a region on the silhouette. Quick zones (scalp, palms, folds…)
    /// lie inside silhouette zones, so they are not added — the sum caps overlaps,
    /// e.g. `front.head` («Face») together with `quick.face`.
    static let regionArea: [BodyRegion: Double] = {
        let quickIDs = Set(BodyZone.quickZones.map(\.id))
        return BodyZone.all
            .filter { !quickIDs.contains($0.id) }
            .reduce(into: [:]) { $0[$1.region, default: 0] += $1.area }
    }()

    /// PASI area score 0–6 from the affected share of a region, in percent.
    static func areaScore(percent: Double) -> Int {
        switch percent {
        case ..<0.000_1: 0
        case ..<10: 1
        case ..<30: 2
        case ..<50: 3
        case ..<70: 4
        case ..<90: 5
        default: 6
        }
    }

    /// - Parameters:
    ///   - scores: latest assessment per zone; for duplicate zone ids the last one wins.
    ///     Unknown zone ids are ignored.
    ///   - dlqi: latest DLQI score, if any (rule of tens).
    ///   - arthritisSuspected: e.g. positive PEST; upgrades the category like a special site.
    static func snapshot(for scores: [ZoneScore], dlqi: Int? = nil, arthritisSuspected: Bool = false) -> SeveritySnapshot {
        var latest: [String: ZoneScore] = [:]
        for score in scores { latest[score.zoneID] = score }

        // Clamp each zone to its reference area and each sign to 0–4.
        var affectedArea: [BodyRegion: Double] = [:]
        var signSums: [BodyRegion: (weight: Double, erythema: Double, induration: Double, scale: Double)] = [:]
        var specialSites: Set<String> = []

        for score in latest.values {
            guard let zone = BodyZone.zone(id: score.zoneID), score.isAffected else { continue }
            if zone.isSpecialSite { specialSites.insert(zone.id) }

            let area = min(max(score.palms, 0), zone.area)
            guard area > 0 else { continue }
            affectedArea[zone.region, default: 0] += area

            // Signs are averaged over the region, weighted by affected area.
            var sums = signSums[zone.region] ?? (0, 0, 0, 0)
            sums.weight += area
            sums.erythema += area * Double(clampSign(score.erythema))
            sums.induration += area * Double(clampSign(score.induration))
            sums.scale += area * Double(clampSign(score.scale))
            signSums[zone.region] = sums
        }

        var bsa = 0.0
        var index = 0.0
        for region in BodyRegion.allCases {
            let total = regionArea[region] ?? 0
            let area = min(affectedArea[region] ?? 0, total)
            bsa += area

            guard total > 0, let sums = signSums[region], sums.weight > 0 else { continue }
            let signs = (sums.erythema + sums.induration + sums.scale) / sums.weight
            index += weight(of: region) * signs * Double(areaScore(percent: area / total * 100))
        }
        bsa = min(bsa, 100)

        let base = baseCategory(bsa: bsa, severityIndex: index, dlqi: dlqi)
        let isElevated = !specialSites.isEmpty || arthritisSuspected
        // A special site or arthritis rules out «mild» even when BSA is small.
        let category = isElevated ? max(base, .moderate) : base

        return SeveritySnapshot(
            bsa: bsa,
            severityIndex: index,
            specialSiteIDs: BodyZone.all.map(\.id).filter(specialSites.contains),
            category: category,
            isElevated: isElevated
        )
    }

    static func snapshot(for assessments: [ZoneAssessment], dlqi: Int? = nil, arthritisSuspected: Bool = false) -> SeveritySnapshot {
        snapshot(for: assessments.map(\.score), dlqi: dlqi, arthritisSuspected: arthritisSuspected)
    }

    /// Category from numbers only: mild < 3 % ≤ moderate ≤ 10 % < severe; index or DLQI > 10 is severe.
    static func baseCategory(bsa: Double, severityIndex: Double, dlqi: Int?) -> SeverityCategory {
        if bsa > Threshold.tens || severityIndex > Threshold.tens || Double(dlqi ?? 0) > Threshold.tens {
            return .severe
        }
        return bsa < Threshold.mildBSA ? .mild : .moderate
    }

    private static func clampSign(_ value: Int) -> Int { min(max(value, 0), 4) }
}
