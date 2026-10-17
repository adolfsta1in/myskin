import Foundation
import Testing
@testable import MySkin

struct PaywallOfferTests {
    private let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

    private func option(_ plan: PaywallPlan, _ price: String, trial: Int?) -> PaywallOption {
        PaywallOption(plan: plan, displayPrice: "$\(price)", price: Decimal(string: price) ?? 0, priceFormat: usd, trialDays: trial)
    }

    @Test func productIDsAreStable() {
        #expect(PaywallPlan.yearly.productID == "app.myskin.ios.premium.yearly")
        #expect(PaywallPlan.weekly.productID == "app.myskin.ios.premium.weekly")
        #expect(PaywallPlan(productID: "app.myskin.ios.premium.weekly") == .weekly)
        #expect(PaywallPlan(productID: "other") == nil)
        #expect(PaywallPlan.preselected == .yearly)
    }

    @Test func savingsRoundDown() {
        // 59.99 vs 9.99 × 52 = 519.48 → 88.45 % → 88.
        #expect(PaywallOffer.savingsPercent(yearly: Decimal(string: "59.99")!, weekly: Decimal(string: "9.99")!) == 88)
        #expect(PaywallOffer.savingsPercent(yearly: 600, weekly: 10) == nil)
        #expect(PaywallOffer.savingsPercent(yearly: 0, weekly: 10) == nil)
    }

    @Test func weeklyEquivalentRoundsDownToCents() {
        #expect(PaywallOffer.weeklyEquivalent(ofYearly: Decimal(string: "59.99")!) == Decimal(string: "1.15")!)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    @Test func trialTimelineShowsRealDates() throws {
        let start = try #require(utc.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 9)))
        let english = Locale(identifier: "en_US")
        let steps = PaywallOffer.trialTimeline(trialDays: 7, canRemind: true, start: start, calendar: utc, locale: english)
        // A 7-day trial from Oct 17 ends and bills on Oct 24; the reminder comes 2 days before.
        #expect(steps.map(\.title) == ["Today", "Oct 22", "Oct 24"])
        #expect(steps[1].detail.contains("remind"))
        let noPermission = PaywallOffer.trialTimeline(trialDays: 7, canRemind: false, start: start, calendar: utc, locale: english)
        #expect(!noPermission[1].detail.contains("We'll"))
        #expect(PaywallOffer.trialTimeline(trialDays: 2, canRemind: true, start: start, calendar: utc, locale: english).map(\.title) == ["Today", "Oct 19"])
    }

    @Test func reminderComesExactlyTwoDaysBeforeTheEnd() throws {
        let start = try #require(utc.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9)))
        let date = try #require(PaywallOffer.reminderDate(trialStart: start, trialDays: 7, calendar: utc))
        let end = try #require(utc.date(byAdding: .day, value: 7, to: start))
        #expect(end.timeIntervalSince(date) == 2 * 24 * 3600)
        #expect(PaywallOffer.reminderDate(trialStart: start, trialDays: 2, calendar: utc) == nil)
    }

    @Test func texts() {
        let yearly = option(.yearly, "59.99", trial: 7)
        #expect(PaywallOffer.priceLine(for: yearly) == "7 days free, then $59.99/year")
        #expect(PaywallOffer.buttonTitle(for: yearly) == "Start 7-day free trial")
        let weekly = option(.weekly, "9.99", trial: nil)
        #expect(PaywallOffer.priceLine(for: weekly) == "$9.99/week")
        #expect(PaywallOffer.buttonTitle(for: weekly) == "Continue")
        #expect(PaywallOffer.paidTimeline(for: weekly).map(\.title) == ["Today", "Every week"])
    }

    @Test func trialDaysFromPeriod() {
        #expect(PaywallOffer.trialDays(periodValue: 1, unit: .week) == 7)
        #expect(PaywallOffer.trialDays(periodValue: 3, unit: .day) == 3)
    }

    @Test func paywallLinksToOurTermsAndPrivacy() {
        #expect(PaywallLinks.terms == AppLinks.terms)
        #expect(PaywallLinks.privacy == AppLinks.privacy)
    }
}
