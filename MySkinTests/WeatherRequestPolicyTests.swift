import Foundation
import Testing
@testable import MySkin

struct WeatherRequestPolicyTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func may(
        lastSuccess: Date? = nil,
        lastFailure: Date? = nil,
        isManual: Bool = false,
        daily: WeatherRequestPolicy.DailyCount? = nil
    ) -> Bool {
        WeatherRequestPolicy.mayRequest(
            now: now, lastSuccess: lastSuccess, lastFailure: lastFailure,
            isManual: isManual, daily: daily, calendar: calendar
        )
    }

    @Test func firstRequestIsAllowed() {
        #expect(may())
    }

    @Test func freshReadingIsReused() {
        #expect(!may(lastSuccess: now.addingTimeInterval(-59 * 60)))
        #expect(may(lastSuccess: now.addingTimeInterval(-61 * 60)))
    }

    @Test func waitsAfterFailureUnlessManual() {
        let failure = now.addingTimeInterval(-60)
        #expect(!may(lastFailure: failure))
        #expect(may(lastFailure: failure, isManual: true))
        #expect(may(lastFailure: now.addingTimeInterval(-6 * 60)))
    }

    @Test func dailyCapHoldsEvenForManualRetries() {
        let full = WeatherRequestPolicy.DailyCount(day: calendar.startOfDay(for: now), count: WeatherRequestPolicy.maxPerDay)
        #expect(!may(daily: full))
        #expect(!may(isManual: true, daily: full))
    }

    @Test func countStartsOverOnANewDay() throws {
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let old = WeatherRequestPolicy.DailyCount(day: calendar.startOfDay(for: yesterday), count: WeatherRequestPolicy.maxPerDay)
        #expect(may(daily: old))
        let next = old.adding(on: now, calendar: calendar)
        #expect(next.count == 1)
        #expect(next.day == calendar.startOfDay(for: now))
    }
}
