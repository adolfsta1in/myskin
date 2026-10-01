import Foundation

extension DoseScheduler {
    /// Planned doses whose time is in `start…end`, and how many of them were marked done.
    static func adherence(
        schedule: DoseSchedule,
        logs: [LoggedDose],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> (done: Int, planned: Int) {
        var done = 0
        var planned = 0
        var day = calendar.startOfDay(for: max(start, schedule.startDate))
        let lastDay = calendar.startOfDay(for: end)
        while day <= lastDay {
            for dose in doses(on: day, schedule: schedule, logs: logs, calendar: calendar)
            where dose.scheduledAt >= start && dose.scheduledAt <= end {
                planned += 1
                if dose.status == .done { done += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (done, planned)
    }
}

/// Everything the doctor report shows for one period, computed from stored records (spec §5 п.9).
struct DoctorReport {
    struct TreatmentLine: Equatable, Identifiable {
        let id: String
        let name: String
        let kind: TreatmentKind
        let schedule: String
        let startDate: Date
        let endDate: Date?
        let stopReason: String?
        /// Done / planned doses in the period; nil for «as needed» or nothing planned.
        let adherence: Double?
    }

    struct PhotoPair: Equatable, Identifiable {
        let zoneID: String
        let before: String
        let now: String
        var id: String { zoneID }
    }

    let start: Date
    let end: Date
    let psoriasisTypes: [PsoriasisType]
    /// Body map at the start of the period (or its first assessment day, if the map started later) and now.
    /// `severityBefore` is nil when there is only one map state to show.
    let severityBefore: SeveritySnapshot?
    let severityNow: SeveritySnapshot?
    /// Average itch in the first and last `itchWindowDays` of the period.
    let itchBefore: Double?
    let itchNow: Double?
    let checkInDays: Int
    let flareDays: Int
    let dlqiFirst: Int?
    let dlqiLatest: Int?
    /// Latest PEST at all (screening lasts beyond the period).
    let pestLatest: Int?
    let treatments: [TreatmentLine]
    /// Logged triggers in the period, most frequent first.
    let triggers: [(trigger: Trigger, days: Int)]
    let photos: [PhotoPair]

    static let itchWindowDays = 14
    static let maxPhotoZones = 3

    struct TreatmentInput {
        let id: String
        let name: String
        let kind: TreatmentKind
        let schedule: DoseSchedule
        let stopReason: String?
        let logs: [LoggedDose]
    }

    struct PhotoInput {
        let zoneID: String
        let day: Date
        let fileName: String
    }

    static func make(
        periodDays: Int,
        endingOn date: Date,
        psoriasisTypes: [PsoriasisType],
        checkIns: [DailyCheckInSample],
        zones: [DatedZoneScore],
        results: [(kind: QuestionnaireKind, date: Date, score: Int)],
        treatments: [TreatmentInput],
        photos: [PhotoInput],
        calendar: Calendar = .current
    ) -> DoctorReport {
        let start = Trends.periodStart(endingOn: date, days: periodDays, calendar: calendar)
        let samples = checkIns.map(\.sample)
        let inPeriod = checkIns.filter { calendar.startOfDay(for: $0.day) >= start && $0.day <= date }

        // Severity: the map as it stood the day before the period (or after its first assessment day) vs now.
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let assessedDays = Set(zones.map { calendar.startOfDay(for: $0.day) }.filter { $0 >= start && $0 <= date })
        var beforeDay: Date? = zones.contains { calendar.startOfDay(for: $0.day) <= dayBefore } ? dayBefore : assessedDays.min()
        // Only one assessment day in the period and nothing earlier: no «before».
        if let day = beforeDay, day >= start, assessedDays.count < 2 { beforeDay = nil }
        let mapBefore = beforeDay.map { Trends.map(on: $0, zones: zones, calendar: calendar) } ?? []
        let mapNow = Trends.map(on: date, zones: zones, calendar: calendar)
        let dlqiLatestEver = results.filter { $0.kind == .dlqi && $0.date <= date }.max { $0.date < $1.date }?.score
        let pest = results.filter { $0.kind == .pest && $0.date <= date }.max { $0.date < $1.date }?.score
        let arthritis = pest.map(PEST.suggestsRheumatologist) ?? false
        let severityBefore = mapBefore.isEmpty ? nil : SeverityCalculator.snapshot(for: mapBefore, arthritisSuspected: arthritis)
        let severityNow = mapNow.isEmpty ? nil : SeverityCalculator.snapshot(for: mapNow, dlqi: dlqiLatestEver, arthritisSuspected: arthritis)

        // Itch: first vs last two weeks of the period.
        let window = min(itchWindowDays, periodDays)
        let firstWindowEnd = calendar.date(byAdding: .day, value: window - 1, to: start) ?? start
        let lastWindowStart = Trends.periodStart(endingOn: date, days: window, calendar: calendar)
        let itchBefore = Trends.averageItch(checkIns: samples, from: start, to: firstWindowEnd, calendar: calendar)
        let itchNow = Trends.averageItch(checkIns: samples, from: lastWindowStart, to: date, calendar: calendar)

        let flareDays = inPeriod.filter {
            !FlareDetector.signals(on: $0.day, checkIns: samples, zones: zones, calendar: calendar).isEmpty
        }.count

        let dlqi = Trends.scores(.dlqi, results: results, from: start, to: date, calendar: calendar)

        // Treatments used at any time during the period.
        let lines = treatments
            .filter { $0.schedule.startDate <= date && ($0.schedule.endDate.map { $0 >= start } ?? true) }
            .sorted { $0.schedule.startDate < $1.schedule.startDate }
            .map { input -> TreatmentLine in
                let counts = DoseScheduler.adherence(schedule: input.schedule, logs: input.logs, from: start, to: date, calendar: calendar)
                return TreatmentLine(
                    id: input.id, name: input.name, kind: input.kind,
                    schedule: DoseScheduler.summary(for: input.schedule, calendar: calendar),
                    startDate: input.schedule.startDate, endDate: input.schedule.endDate, stopReason: input.stopReason,
                    adherence: counts.planned > 0 ? Double(counts.done) / Double(counts.planned) : nil
                )
            }

        var triggerDays: [Trigger: Int] = [:]
        for checkIn in inPeriod {
            for trigger in Set(checkIn.triggers) { triggerDays[trigger, default: 0] += 1 }
        }
        let triggers = Trigger.allCases
            .compactMap { trigger in triggerDays[trigger].map { (trigger: trigger, days: $0) } }
            .sorted { $0.days > $1.days }

        return DoctorReport(
            start: start,
            end: date,
            psoriasisTypes: psoriasisTypes,
            severityBefore: severityBefore,
            severityNow: severityNow,
            itchBefore: itchBefore,
            itchNow: itchNow,
            checkInDays: Set(inPeriod.map { calendar.startOfDay(for: $0.day) }).count,
            flareDays: flareDays,
            dlqiFirst: dlqi.count > 1 ? dlqi.first.map { Int($0.value) } : nil,
            dlqiLatest: dlqi.last.map { Int($0.value) },
            pestLatest: pest,
            treatments: lines,
            triggers: triggers,
            photos: photoPairs(photos, from: start, to: date, calendar: calendar)
        )
    }

    /// Up to `maxPhotoZones` zones with 2+ photos in the period: oldest and newest, most recent zones first.
    static func photoPairs(_ photos: [PhotoInput], from start: Date, to end: Date, calendar: Calendar = .current) -> [PhotoPair] {
        let inPeriod = photos.filter { calendar.startOfDay(for: $0.day) >= start && $0.day <= end }
        let byZone = Dictionary(grouping: inPeriod, by: \.zoneID)
        return byZone.compactMap { zoneID, group -> (PhotoPair, Date)? in
            let sorted = group.sorted { $0.day < $1.day }
            guard sorted.count > 1, let first = sorted.first, let last = sorted.last else { return nil }
            return (PhotoPair(zoneID: zoneID, before: first.fileName, now: last.fileName), last.day)
        }
        .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.zoneID < $1.0.zoneID) }
        .prefix(maxPhotoZones)
        .map(\.0)
    }

    /// True if there is nothing to report in the period.
    var isEmpty: Bool {
        severityNow == nil && checkInDays == 0 && dlqiLatest == nil && pestLatest == nil && treatments.isEmpty
    }
}

/// Value copy of the check-in fields the report needs.
struct DailyCheckInSample: Hashable, Sendable {
    let day: Date
    let itch: Int
    var newSpots: Bool = false
    var triggers: [Trigger] = []

    var sample: CheckInSample { CheckInSample(day: day, itch: itch, newSpots: newSpots) }
}

extension DailyCheckIn {
    var reportSample: DailyCheckInSample { DailyCheckInSample(day: day, itch: itch, newSpots: newSpots, triggers: triggers) }
}
