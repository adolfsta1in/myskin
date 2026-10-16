import Foundation
import Testing
@testable import MySkin

/// Across 30 fixed diaries: a real effect is found after four weeks, noise rarely is.
/// Serialized: the reports are heavy for a phone when run in parallel.
@Suite(.serialized) struct PatternsCalibrationTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC") ?? .gmt; return c
    }()

    private func run(seed: UInt64, count: Int, effect: Double, tags: Int) -> (falseFindings: Int, found: Bool) {
        var state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
        func unit() -> Double { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return Double(state % 1_000_000) / 1_000_000 }
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12)) ?? .now
        var days: [PatternDay] = []
        var drift = 0.0
        for i in 0..<count {
            var d = PatternDay(day: calendar.date(byAdding: .day, value: i, to: start) ?? start, itch: 0, foods: unit() < 0.3 ? [.dairy] : [])
            d.customTags = (0..<tags).filter { _ in unit() < 0.3 }.map { "tag\($0)" }
            if unit() < 0.25 { d.triggers = [.stress] }
            d.humidity = 30 + unit() * 50
            d.sleep = Int(unit() * 10)
            days.append(d)
            drift = 0.6 * drift + (unit() - 0.5) * 2.4
            let exposed = (2...3).contains { i - $0 >= 0 && (days[i - $0].foods ?? []).contains(.dairy) }
            days[i].itch = min(max(Int((4.5 + drift + (exposed ? effect : 0)).rounded()), 0), 10)
        }
        let report = Patterns.report(days: days, calendar: calendar)
        return (report.findings.filter { $0.factor != .food(.dairy) }.count, report.findings.contains { $0.factor == .food(.dairy) && $0.direction == .worse })
    }

    private func tally(count: Int, effect: Double) -> (runsWithFalse: Int, found: Int) {
        var runsWithFalse = 0, found = 0
        for seed in 1...30 {
            let result = run(seed: UInt64(seed), count: count, effect: effect, tags: 15)
            if result.falseFindings > 0 { runsWithFalse += 1 }
            if result.found { found += 1 }
        }
        return (runsWithFalse, found)
    }

    @Test func realEffectFoundAfterFourWeeks() {
        let result = tally(count: 28, effect: 2)
        #expect(result.found >= 24)
        #expect(result.runsWithFalse <= 3)
    }

    @Test func pureNoiseRarelyGivesFindings() {
        #expect(tally(count: 28, effect: 0).runsWithFalse <= 3)
        #expect(tally(count: 90, effect: 0).runsWithFalse <= 3)
    }
}
