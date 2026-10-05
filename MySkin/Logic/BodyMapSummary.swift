import Foundation

/// What the Body tab shows: the current map (latest assessment of each zone), its severity and
/// the change against the map before the latest assessment day.
struct BodyMapSummary: Equatable {
    /// Latest score of each zone, keyed by `BodyZone.id`.
    let current: [String: ZoneScore]
    let snapshot: SeveritySnapshot
    /// Severity before the latest assessment day; nil if there was no earlier assessment.
    let previous: SeveritySnapshot?
    /// Day of the latest assessment.
    let lastAssessed: Date?

    static let empty = BodyMapSummary(current: [:], snapshot: .empty, previous: nil, lastAssessed: nil)

    /// Map color level 0–3 per zone (`SeverityCalculator.level`).
    var levels: [String: Int] {
        current.compactMapValues { score in
            let level = SeverityCalculator.level(for: score)
            return level == 0 ? nil : level
        }
    }

    /// BSA change in percentage points vs the previous map.
    var bsaChange: Double? { previous.map { snapshot.bsa - $0.bsa } }

    static func make(
        zones: [DatedZoneScore],
        dlqi: Int? = nil,
        arthritisSuspected: Bool = false,
        calendar: Calendar = .current
    ) -> BodyMapSummary {
        guard let lastDay = zones.map({ calendar.startOfDay(for: $0.day) }).max() else { return .empty }
        let sorted = zones.sorted { $0.day < $1.day }
        let earlier = sorted.filter { calendar.startOfDay(for: $0.day) < lastDay }

        let current = latest(sorted)
        let snapshot = SeverityCalculator.snapshot(for: Array(current.values), dlqi: dlqi, arthritisSuspected: arthritisSuspected)
        let previous = earlier.isEmpty
            ? nil
            : SeverityCalculator.snapshot(for: Array(latest(earlier).values), dlqi: dlqi, arthritisSuspected: arthritisSuspected)
        return BodyMapSummary(current: current, snapshot: snapshot, previous: previous, lastAssessed: lastDay)
    }

    /// Each zone keeps its latest score; `zones` must be sorted by day.
    private static func latest(_ zones: [DatedZoneScore]) -> [String: ZoneScore] {
        zones.reduce(into: [:]) { $0[$1.score.zoneID] = $1.score }
    }
}

extension SeverityCalculator {
    /// Map color level for one zone: 0 clear, 1 mild, 2 moderate, 3 severe.
    /// Uses the average of redness, thickness and scaling; a zone with only area or pustules is mild at least.
    static func level(for score: ZoneScore) -> Int {
        guard score.isAffected else { return 0 }
        let signs = [score.erythema, score.induration, score.scale].map { min(max($0, 0), 4) }
        let average = Double(signs.reduce(0, +)) / 3
        switch average {
        case ..<1.5: return 1
        case ..<2.5: return 2
        default: return 3
        }
    }
}
