import Foundation
import Testing
@testable import MyApp

struct DoctorReportTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 22)) ?? .now }
    private func daysAgo(_ n: Int, hour: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: today)) ?? today
        return day.addingTimeInterval(TimeInterval(hour * 3600))
    }

    private func make(
        days: Int = 30,
        checkIns: [DailyCheckInSample] = [],
        zones: [DatedZoneScore] = [],
        results: [(kind: QuestionnaireKind, date: Date, score: Int)] = [],
        treatments: [DoctorReport.TreatmentInput] = [],
        photos: [DoctorReport.PhotoInput] = []
    ) -> DoctorReport {
        DoctorReport.make(
            periodDays: days, endingOn: today, psoriasisTypes: [.plaque], checkIns: checkIns, zones: zones,
            results: results, treatments: treatments, photos: photos, calendar: calendar
        )
    }

    @Test func emptyDiaryIsEmpty() {
        let report = make()
        #expect(report.isEmpty)
        #expect(report.severityNow == nil)
        #expect(report.itchNow == nil)
    }

    @Test func severityBeforeAndNow() {
        let zones = [
            DatedZoneScore(day: daysAgo(60), score: ZoneScore(zoneID: "front.thigh.left", palms: 4, erythema: 2)),
            DatedZoneScore(day: daysAgo(5), score: ZoneScore(zoneID: "front.thigh.left", palms: 1, erythema: 1)),
        ]
        let report = make(zones: zones)
        #expect(report.severityBefore?.bsa == 4)
        #expect(report.severityNow?.bsa == 1)
    }

    @Test func singleAssessmentHasNoBefore() {
        let report = make(zones: [DatedZoneScore(day: daysAgo(5), score: ZoneScore(zoneID: "quick.scalp", palms: 1, erythema: 1))])
        #expect(report.severityBefore == nil)
        #expect(report.severityNow?.specialSiteIDs == ["quick.scalp"])
    }

    @Test func periodChangesTheNumbers() {
        let zones = [
            DatedZoneScore(day: daysAgo(100), score: ZoneScore(zoneID: "front.thigh.left", palms: 4, erythema: 2)),
            DatedZoneScore(day: daysAgo(50), score: ZoneScore(zoneID: "front.thigh.left", palms: 2, erythema: 2)),
            DatedZoneScore(day: daysAgo(5), score: ZoneScore(zoneID: "front.thigh.left", palms: 1, erythema: 1)),
        ]
        #expect(make(days: 30, zones: zones).severityBefore?.bsa == 2)
        #expect(make(days: 182, zones: zones).severityBefore?.bsa == 4)
    }

    @Test func itchFirstAndLastTwoWeeks() {
        let checkIns = [
            DailyCheckInSample(day: daysAgo(29), itch: 8, triggers: [.stress]),
            DailyCheckInSample(day: daysAgo(25), itch: 6, triggers: [.stress, .alcohol]),
            DailyCheckInSample(day: daysAgo(2), itch: 2),
            DailyCheckInSample(day: daysAgo(40), itch: 10, triggers: [.alcohol]),
        ]
        let report = make(checkIns: checkIns)
        #expect(report.itchBefore == 7)
        #expect(report.itchNow == 2)
        #expect(report.checkInDays == 3)
        #expect(report.flareDays == 1) // itch 8
        #expect(report.triggers.map(\.trigger) == [.stress, .alcohol])
        #expect(report.triggers.first?.days == 2)
    }

    @Test func questionnaires() {
        let results: [(kind: QuestionnaireKind, date: Date, score: Int)] = [
            (.dlqi, daysAgo(25), 12), (.dlqi, daysAgo(3), 4), (.pest, daysAgo(200), 3), (.dlqi, daysAgo(90), 20),
        ]
        let report = make(results: results)
        #expect(report.dlqiFirst == 12)
        #expect(report.dlqiLatest == 4)
        #expect(report.pestLatest == 3)
        #expect(report.severityNow == nil)
    }

    @Test func adherenceCountsDoneDosesInPeriod() {
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 1, doseMinutes: [8 * 60], startDate: daysAgo(3))
        let logs = [
            LoggedDose(scheduledAt: daysAgo(3, hour: 8), status: .done),
            LoggedDose(scheduledAt: daysAgo(2, hour: 8), status: .skipped),
            LoggedDose(scheduledAt: daysAgo(1, hour: 8), status: .done),
        ]
        // 4 planned doses (3 days ago … today 08:00), 2 done.
        let counts = DoseScheduler.adherence(schedule: schedule, logs: logs, from: daysAgo(29), to: today, calendar: calendar)
        #expect(counts.planned == 4)
        #expect(counts.done == 2)

        let treatment = DoctorReport.TreatmentInput(id: "a", name: "Cream", kind: .cream, schedule: schedule, stopReason: nil, logs: logs)
        let stopped = DoctorReport.TreatmentInput(
            id: "b", name: "Old", kind: .pill,
            schedule: DoseSchedule(kind: .timesPerDay, startDate: daysAgo(200), endDate: daysAgo(100)),
            stopReason: "Side effects", logs: []
        )
        let report = make(treatments: [treatment, stopped])
        #expect(report.treatments.map(\.name) == ["Cream"])
        #expect(report.treatments.first?.adherence == 0.5)
    }

    @Test func photoPairsNeedTwoPhotosInPeriod() {
        let photos = [
            DoctorReport.PhotoInput(zoneID: "quick.scalp", day: daysAgo(20), fileName: "a.jpg"),
            DoctorReport.PhotoInput(zoneID: "quick.scalp", day: daysAgo(10), fileName: "b.jpg"),
            DoctorReport.PhotoInput(zoneID: "quick.scalp", day: daysAgo(1), fileName: "c.jpg"),
            DoctorReport.PhotoInput(zoneID: "front.knee.left", day: daysAgo(2), fileName: "d.jpg"),
            DoctorReport.PhotoInput(zoneID: "front.knee.left", day: daysAgo(90), fileName: "e.jpg"),
        ]
        let pairs = make(photos: photos).photos
        #expect(pairs == [DoctorReport.PhotoPair(zoneID: "quick.scalp", before: "a.jpg", now: "c.jpg")])
    }
}
