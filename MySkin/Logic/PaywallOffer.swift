import Foundation

/// Subscription plans on the paywall. rawValue is stable (A/B analytics, saved choice) — don't rename.
nonisolated enum PaywallPlan: String, CaseIterable, Sendable {
    case yearly
    case weekly

    /// App Store Connect product ids — don't rename: purchases are tied to them.
    var productID: String {
        switch self {
        case .yearly: "app.myskin.ios.premium.yearly"
        case .weekly: "app.myskin.ios.premium.weekly"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    /// Preselected plan: the yearly one shows the saving.
    static let preselected: PaywallPlan = .yearly
}

/// A plan as the paywall shows it. Built from a StoreKit `Product`; no StoreKit types here.
nonisolated struct PaywallOption: Identifiable, Equatable, Sendable {
    let plan: PaywallPlan
    /// Localized price from the App Store, e.g. "$59.99".
    let displayPrice: String
    let price: Decimal
    let priceFormat: Decimal.FormatStyle.Currency
    /// Free trial length in days, only if this user is still eligible for it.
    let trialDays: Int?

    var id: PaywallPlan { plan }

    func formatted(_ value: Decimal) -> String { value.formatted(priceFormat) }
}

/// One row of the "how your free trial works" timeline.
nonisolated struct TrialStep: Equatable, Sendable {
    enum Icon: Equatable, Sendable { case unlock, reminder, renewal }

    let icon: Icon
    let title: String
    let detail: String
}

/// Pure paywall maths and texts (prices come from StoreKit, never hard-coded).
nonisolated enum PaywallOffer {
    static let weeksPerYear: Decimal = 52
    /// Reminder goes out this many days before the trial ends.
    static let reminderDaysBeforeEnd = 2

    /// Whole percent the yearly plan saves against paying weekly for a year (rounded down,
    /// so the badge never overstates). nil if there's no saving.
    static func savingsPercent(yearly: Decimal, weekly: Decimal) -> Int? {
        let weeklyPerYear = weekly * weeksPerYear
        guard yearly > 0, weeklyPerYear > yearly else { return nil }
        let ratio = (1 - yearly / weeklyPerYear) * 100
        var value = ratio
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .down)
        let percent = NSDecimalNumber(decimal: rounded).intValue
        return percent > 0 ? percent : nil
    }

    /// Yearly price per week, rounded down to cents ("$1.15/week").
    static func weeklyEquivalent(ofYearly yearly: Decimal) -> Decimal {
        var value = yearly / weeksPerYear
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .down)
        return rounded
    }

    /// Day (counted from 1 = today) the trial-ending reminder arrives; nil for trials too short for it.
    static func reminderDay(trialDays: Int) -> Int? {
        let day = trialDays - reminderDaysBeforeEnd
        return day > 1 ? day : nil
    }

    /// When to send the reminder for a trial that started at `start`.
    static func reminderDate(trialStart start: Date, trialDays: Int, calendar: Calendar = .current) -> Date? {
        guard let day = reminderDay(trialDays: trialDays) else { return nil }
        return calendar.date(byAdding: .day, value: day - 1, to: start)
    }

    /// Timeline for a free trial. The reminder row promises a notification only if we can send one.
    static func trialTimeline(trialDays: Int, canRemind: Bool) -> [TrialStep] {
        var steps = [TrialStep(
            icon: .unlock,
            title: "Today",
            detail: "Check-ins, body map and photos — know your patterns over time and share a report with your doctor."
        )]
        if let day = reminderDay(trialDays: trialDays) {
            steps.append(TrialStep(
                icon: .reminder,
                title: "Day \(day)",
                detail: canRemind
                    ? "We'll remind you that your trial ends soon."
                    : "Your trial ends in \(reminderDaysBeforeEnd) days. Cancel anytime in Settings."
            ))
        }
        steps.append(TrialStep(
            icon: .renewal,
            title: "Day \(trialDays)",
            detail: "Your subscription starts. Cancel before then to avoid being charged."
        ))
        return steps
    }

    /// Same timeline shape for a plan without a trial: what happens today and on renewal.
    static func paidTimeline(for option: PaywallOption) -> [TrialStep] {
        [
            TrialStep(
                icon: .unlock,
                title: "Today",
                detail: "Check-ins, body map and photos — know your patterns over time and share a report with your doctor."
            ),
            TrialStep(
                icon: .renewal,
                title: option.plan == .weekly ? "Every week" : "Every year",
                detail: "\(option.displayPrice) renews automatically. Cancel anytime in Settings."
            ),
        ]
    }

    /// Main price line under the plans, e.g. "7 days free, then $59.99/year".
    static func priceLine(for option: PaywallOption) -> String {
        let period = option.plan == .yearly ? "year" : "week"
        if let days = option.trialDays {
            return "\(days) days free, then \(option.displayPrice)/\(period)"
        }
        return "\(option.displayPrice)/\(period)"
    }

    static func buttonTitle(for option: PaywallOption) -> String {
        option.trialDays.map { "Start \($0)-day free trial" } ?? "Continue"
    }

    /// Trial length from an introductory offer period (StoreKit gives value + unit).
    static func trialDays(periodValue: Int, unit: TrialPeriodUnit) -> Int {
        switch unit {
        case .day: periodValue
        case .week: periodValue * 7
        case .month: periodValue * 30
        case .year: periodValue * 365
        }
    }

    enum TrialPeriodUnit: Sendable { case day, week, month, year }
}
