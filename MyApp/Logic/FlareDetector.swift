import Foundation

// MARK: - Input

/// Value copy of the `DailyCheckIn` fields the detector needs.
struct CheckInSample: Hashable, Sendable {
    let day: Date
    let itch: Int
    var newSpots: Bool = false
}

extension DailyCheckIn {
    var sample: CheckInSample { CheckInSample(day: day, itch: itch, newSpots: newSpots) }
}

/// A zone score together with its assessment day.
struct DatedZoneScore: Hashable, Sendable {
    let day: Date
    let score: ZoneScore
}

extension ZoneAssessment {
    var datedScore: DatedZoneScore { DatedZoneScore(day: day, score: score) }
}

// MARK: - Output

/// Why the app switched to Flare mode — shown under «Flare mode · why?».
enum FlareReason: Hashable, Sendable {
    case highItch(Int)
    case itchSpike(itch: Int, average: Double)
    case bsaIncrease(from: Double, to: Double)
    /// `BodyZone.id` values, in `BodyZone.all` order.
    case newZones([String])
    case newSpots

    var explanation: String {
        switch self {
        case .highItch(let itch):
            "Itch was \(itch)/10."
        case .itchSpike(let itch, let average):
            "Itch was \(itch)/10, well above your recent average of \(average.formatted(.number.precision(.fractionLength(1))))."
        case .bsaIncrease(let from, let to):
            "Affected area grew from \(from.formatted(.number.precision(.fractionLength(1)))) % to \(to.formatted(.number.precision(.fractionLength(1)))) %."
        case .newZones(let ids):
            "New area marked: \(ids.compactMap { BodyZone.zone(id: $0)?.name }.formatted(.list(type: .and)))."
        case .newSpots:
            "You noted new or spreading spots."
        }
    }
}

struct FlareStatus: Equatable {
    let mode: AppMode
    /// Signals of the most recent day that had any; empty in Calm.
    let reasons: [FlareReason]
    /// Day the reasons were seen on.
    let signalDay: Date?

    static let calm = FlareStatus(mode: .calm, reasons: [], signalDay: nil)
}

// MARK: - Detector

/// Automatic Calm / Flare mode (migration plan §1.6). The mode is computed, never stored.
///
/// A day «has signs» when any rule fires on it. The mode is Flare while one of the last
/// `calmDays` days has signs, so it returns to Calm after that many days in a row without signs.
/// Days without a check-in count as days without signs.
enum FlareDetector {
    /// Thresholds in one place so they are easy to tune.
    enum Threshold {
        /// Itch at or above this is a flare signal.
        static let highItch = 7
        /// Itch this many points above the recent average is a flare signal.
        static let itchSpike = 3.0
        /// Days before the check-in used for the average.
        static let averageWindowDays = 7
        /// Check-ins needed for the average and for any Flare at all.
        static let minCheckIns = 3
        /// BSA growth in percentage points vs the previous assessment.
        static let bsaIncrease = 1.0
        /// Days in a row without signs before returning to Calm.
        static let calmDays = 3
    }

    static func status(
        on date: Date,
        checkIns: [CheckInSample],
        zones: [DatedZoneScore] = [],
        calendar: Calendar = .current
    ) -> FlareStatus {
        let today = calendar.startOfDay(for: date)
        let pastCheckIns = checkIns.filter { calendar.startOfDay(for: $0.day) <= today }
        guard pastCheckIns.count >= Threshold.minCheckIns else { return .calm }

        for offset in 0..<Threshold.calmDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let reasons = signals(on: day, checkIns: pastCheckIns, zones: zones, calendar: calendar)
            if !reasons.isEmpty {
                return FlareStatus(mode: .flare, reasons: reasons, signalDay: day)
            }
        }
        return .calm
    }

    static func status(
        on date: Date,
        checkIns: [DailyCheckIn],
        assessments: [ZoneAssessment],
        calendar: Calendar = .current
    ) -> FlareStatus {
        status(on: date, checkIns: checkIns.map(\.sample), zones: assessments.map(\.datedScore), calendar: calendar)
    }

    /// Flare signals seen on one day.
    static func signals(
        on date: Date,
        checkIns: [CheckInSample],
        zones: [DatedZoneScore],
        calendar: Calendar = .current
    ) -> [FlareReason] {
        let day = calendar.startOfDay(for: date)
        var reasons: [FlareReason] = []

        if let checkIn = checkIns.last(where: { calendar.startOfDay(for: $0.day) == day }) {
            if checkIn.itch >= Threshold.highItch {
                reasons.append(.highItch(checkIn.itch))
            }
            if let windowStart = calendar.date(byAdding: .day, value: -Threshold.averageWindowDays, to: day) {
                let previous = checkIns.filter {
                    let other = calendar.startOfDay(for: $0.day)
                    return other >= windowStart && other < day
                }
                if previous.count >= Threshold.minCheckIns {
                    let average = Double(previous.map(\.itch).reduce(0, +)) / Double(previous.count)
                    if Double(checkIn.itch) - average >= Threshold.itchSpike {
                        reasons.append(.itchSpike(itch: checkIn.itch, average: average))
                    }
                }
            }
            if checkIn.newSpots {
                reasons.append(.newSpots)
            }
        }

        reasons += zoneSignals(on: day, zones: zones, calendar: calendar)
        return reasons
    }

    /// Compares the body map after this day's assessments with the state before it.
    /// Each zone keeps its latest assessment, so a partial update counts as a full map.
    private static func zoneSignals(on day: Date, zones: [DatedZoneScore], calendar: Calendar) -> [FlareReason] {
        let sorted = zones.sorted { $0.day < $1.day }
        let earlier = sorted.filter { calendar.startOfDay(for: $0.day) < day }
        let onDay = sorted.filter { calendar.startOfDay(for: $0.day) == day }
        // The very first map (e.g. onboarding baseline) is not a flare.
        guard !earlier.isEmpty, !onDay.isEmpty else { return [] }

        var before: [String: ZoneScore] = [:]
        for entry in earlier { before[entry.score.zoneID] = entry.score }
        var after = before
        for entry in onDay { after[entry.score.zoneID] = entry.score }

        var reasons: [FlareReason] = []
        let bsaBefore = SeverityCalculator.snapshot(for: Array(before.values)).bsa
        let bsaAfter = SeverityCalculator.snapshot(for: Array(after.values)).bsa
        if bsaAfter - bsaBefore >= Threshold.bsaIncrease {
            reasons.append(.bsaIncrease(from: bsaBefore, to: bsaAfter))
        }

        let newIDs = BodyZone.all.map(\.id).filter { id in
            (after[id]?.isAffected ?? false) && !(before[id]?.isAffected ?? false)
        }
        if !newIDs.isEmpty {
            reasons.append(.newZones(newIDs))
        }
        return reasons
    }
}
