import Foundation
import Testing
@testable import MySkin

struct PatternsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private var start: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12)) ?? .now
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }

    /// Fixed pseudo-random numbers, so every run sees the same diary.
    private struct Noise {
        var state: UInt64
        init(_ seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
        mutating func unit() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 1_000_000) / 1_000_000
        }
        mutating func chance(_ p: Double) -> Bool { unit() < p }
    }

    /// `count` daily check-ins; `build` sets factors, `effect` adds itch from the days built so far.
    private func diary(
        count: Int,
        seed: UInt64 = 1,
        baseItch: (Int) -> Double = { _ in 4 },
        build: (Int, inout PatternDay, inout Noise) -> Void = { _, _, _ in },
        effect: (Int, [PatternDay]) -> Double = { _, _ in 0 }
    ) -> [PatternDay] {
        var noise = Noise(seed)
        var days: [PatternDay] = []
        var drift = 0.0
        for index in 0..<count {
            var entry = PatternDay(day: day(index), itch: 0, foods: [])
            build(index, &entry, &noise)
            days.append(entry)
            // Slowly wandering noise, like real itch.
            drift = 0.5 * drift + (noise.unit() - 0.5) * 1.6
            let itch = baseItch(index) + drift + effect(index, days)
            days[index].itch = min(max(Int(itch.rounded()), 0), 10)
        }
        return days
    }

    private func report(_ days: [PatternDay]) -> PatternReport {
        Patterns.report(days: days, calendar: calendar)
    }

    private func had(_ food: Food, _ days: [PatternDay], _ index: Int, lag: ClosedRange<Int>) -> Bool {
        lag.contains { index - $0 >= 0 && (days[index - $0].foods ?? []).contains(food) }
    }

    // MARK: - Found effects

    @Test func plantedEffectIsFound() throws {
        let days = diary(count: 90, build: { _, day, noise in
            if noise.chance(0.3) { day.foods = [.dairy] }
            if noise.chance(0.4) { day.foods = (day.foods ?? []) + [.coffee] }
        }, effect: { index, days in had(.dairy, days, index, lag: 2...3) ? 3 : 0 })

        let finding = try #require(report(days).findings.first { $0.factor == .food(.dairy) })
        #expect(finding.direction == .worse)
        #expect(finding.strength == .strong)
        #expect(finding.lag == 2...3)
        #expect(!finding.isEarly)
        #expect(finding.meanItchExposed > finding.meanItchUnexposed + 2)
    }

    @Test func noiseFactorIsNotAFinding() {
        let days = diary(count: 90, build: { _, day, noise in
            if noise.chance(0.3) { day.foods = [.dairy] }
            if noise.chance(0.4) { day.foods = (day.foods ?? []) + [.coffee] }
        }, effect: { index, days in had(.dairy, days, index, lag: 2...3) ? 3 : 0 })

        #expect(!report(days).findings.contains { $0.factor == .food(.coffee) })
    }

    @Test func helpfulFactorIsBetter() throws {
        let days = diary(count: 90, seed: 3, baseItch: { _ in 5 }, build: { _, day, noise in
            day.uvIndex = noise.chance(0.3) ? 7 : 2
        }, effect: { index, days in
            (0...1).contains { index - $0 >= 0 && (days[index - $0].uvIndex ?? 0) >= 6 } ? -2 : 0
        })

        let finding = try #require(report(days).findings.first { $0.factor == .highUV })
        #expect(finding.direction == .better)
    }

    /// The point of the feature: something to show after about four weeks of logging.
    @Test func strongEffectShowsAfterFourWeeksAsEarly() throws {
        let days = diary(count: 28, seed: 5, build: { _, day, noise in
            if noise.chance(0.3) { day.foods = [.dairy] }
        }, effect: { index, days in had(.dairy, days, index, lag: 2...3) ? 3 : 0 })

        let finding = try #require(report(days).findings.first { $0.factor == .food(.dairy) })
        #expect(finding.isEarly)
        #expect(finding.strength <= .moderate)
    }

    // MARK: - No false findings

    @Test func trendIsNotAFinding() {
        // Itch falls from 7 to 2 as treatment works; stress was logged mostly at the start.
        let days = diary(count: 90, seed: 7, baseItch: { 7 - 5 * Double($0) / 89 }, build: { index, day, noise in
            if noise.chance(index < 45 ? 0.45 : 0.08) { day.triggers = [.stress] }
        })

        #expect(!report(days).findings.contains { $0.factor == .trigger(.stress) })
    }

    @Test func thirtyNoiseFactorsGiveAtMostOneFalseFinding() {
        let days = diary(count: 120, seed: 11, build: { _, day, noise in
            day.customTags = (0..<30).filter { _ in noise.chance(0.3) }.map { "tag\($0)" }
        })

        #expect(report(days).findings.count <= 1)
    }

    // MARK: - Unknown is not «no»

    @Test func unloggedFoodIsUnknown() {
        let day = PatternDay(day: start, itch: 3)
        #expect(PatternFactor.food(.dairy).isPresent(on: day) == nil)
        #expect(PatternFactor.food(.dairy).isPresent(on: PatternDay(day: start, itch: 3, foods: [])) == false)
        // A trigger that wasn't picked on a check-in counts as absent.
        #expect(PatternFactor.trigger(.stress).isPresent(on: day) == false)
        #expect(PatternFactor.dryAir.isPresent(on: day) == nil)
    }

    @Test func daysWithoutFoodLogAreNotUnexposed() {
        // Food logged only every other day: no 0–1 or 2–3 window is fully known, so nothing to compare.
        let days = diary(count: 60, build: { index, day, _ in
            day.foods = index.isMultiple(of: 2) ? (index % 6 == 0 ? [.dairy] : []) : nil
        })

        let result = report(days)
        #expect(result.notEnoughData.contains { $0.factor == .food(.dairy) })
        #expect(!result.findings.contains { $0.factor == .food(.dairy) })
    }

    @Test func weekLongRunIsOneEpisode() throws {
        let days = diary(count: 40, build: { index, day, _ in
            if (10...16).contains(index) { day.triggers = [.alcohol] }
        })

        let pending = try #require(report(days).notEnoughData.first { $0.factor == .trigger(.alcohol) })
        #expect(pending.episodes == 1)
    }

    // MARK: - Report shape

    @Test func factorsLoggedTogetherAreFlagged() throws {
        let days = diary(count: 90, seed: 13, build: { _, day, noise in
            if noise.chance(0.3) { day.foods = [.dairy, .sugar] }
        }, effect: { index, days in had(.dairy, days, index, lag: 2...3) ? 3 : 0 })

        let finding = try #require(report(days).findings.first { $0.factor == .food(.dairy) })
        #expect(finding.oftenLoggedWith == [Food.sugar.title])
        #expect(finding.hardToTellApart)
        #expect(finding.explanation.contains("hard to tell"))
    }

    @Test func tooFewCheckInsWaits() {
        let result = report(diary(count: 15))
        #expect(result.findings.isEmpty)
        #expect(result.checkInDays == 15)
        #expect(result.checkInsUntilFirstAnalysis == 6)
    }

    @Test func sameInputSameReport() {
        let days = diary(count: 60, seed: 17, build: { _, day, noise in
            if noise.chance(0.3) { day.triggers = [.stress] }
            if noise.chance(0.3) { day.foods = [.dairy] }
        })
        #expect(report(days) == report(days))
    }

    @Test func ownFoodsIgnoreCase() {
        let days = diary(count: 40, build: { index, day, _ in
            if index % 5 == 0 { day.customFoods = [index % 10 == 0 ? "Eggs" : "eggs "] }
        })
        let result = report(days)
        let ids = result.findings.map(\.id) + result.unclear.map(\.id) + result.notEnoughData.map(\.id)
        #expect(ids.filter { $0.hasPrefix("customFood.") } == ["customFood.eggs"])
        let title = (result.unclear.map(\.title) + result.notEnoughData.map(\.title) + result.findings.map(\.title))
            .first { $0.lowercased().hasPrefix("eggs") }
        #expect(title == "Eggs")
    }

    @Test func wordingIsNotMedicalAdvice() throws {
        let days = diary(count: 90, build: { _, day, noise in
            if noise.chance(0.3) { day.foods = [.dairy] }
        }, effect: { index, days in had(.dairy, days, index, lag: 2...3) ? 3 : 0 })
        let finding = try #require(report(days).findings.first)
        #expect(finding.summary == "Itch was higher 2–3 days after dairy")
        let text = finding.explanation.lowercased()
        #expect(text.contains("not proof of cause"))
        #expect(text.contains("doctor"))
        for word in ["causes", "trigger", "avoid"] { #expect(!text.contains(word)) }
    }

    // MARK: - Statistics helpers

    @Test func studentTMatchesTables() {
        // t = 2.228 with 10 df is the two-sided 5 % point.
        #expect(abs(Patterns.studentTwoSidedP(t: 2.228, df: 10) - 0.05) < 0.001)
        #expect(abs(Patterns.studentTwoSidedP(t: 0, df: 10) - 1) < 1e-9)
    }

    @Test func benjaminiHochbergAdjusts() {
        let q = Patterns.benjaminiHochberg([0.01, 0.04, 0.03, 0.5])
        #expect(abs(q[0] - 0.04) < 1e-9)
        #expect(abs(q[1] - 0.04 * 4 / 3) < 1e-9)
        #expect(abs(q[2] - 0.04 * 4 / 3) < 1e-9)
        #expect(abs(q[3] - 0.5) < 1e-9)
    }

    // MARK: - Missed doses

    @Test func missedDosesNeedNearbyMarks() throws {
        let schedule = DoseSchedule(kind: .timesPerDay, timesPerDay: 1, doseMinutes: [9 * 60], startDate: day(0))
        let logs = [LoggedDose(scheduledAt: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day(1)), status: .done)]
        let checkIns = [1, 2, 20].map { PatternDay(day: day($0), itch: 3) }
        let result = PatternInput.days(
            checkIns: checkIns, treatments: [PatternTreatment(schedule: schedule, logs: logs)],
            asOf: day(30), calendar: calendar
        )
        #expect(result[0].missedDose == false)   // marked done
        #expect(result[1].missedDose == true)    // open, and the user was marking doses then
        #expect(result[2].missedDose == nil)     // no marks anywhere near: unknown
    }
}
