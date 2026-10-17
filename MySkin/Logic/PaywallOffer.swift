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

    /// Days after the trial start when the reminder goes out — exactly `reminderDaysBeforeEnd`
    /// before the trial ends. Nil for trials too short for it.
    static func reminderOffsetDays(trialDays: Int) -> Int? {
        let offset = trialDays - reminderDaysBeforeEnd
        return offset >= 1 ? offset : nil
    }

    /// When to send the reminder for a trial that started at `start`.
    static func reminderDate(trialStart start: Date, trialDays: Int, calendar: Calendar = .current) -> Date? {
        guard let offset = reminderOffsetDays(trialDays: trialDays) else { return nil }
        return calendar.date(byAdding: .day, value: offset, to: start)
    }

    /// Timeline for a free trial starting `start`, with real dates: a 7-day trial started
    /// on Oct 17 ends (and bills) on Oct 24. The reminder row promises a notification only if we can send one.
    static func trialTimeline(
        trialDays: Int,
        canRemind: Bool,
        start: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [TrialStep] {
        func title(_ offset: Int) -> String {
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            var style = Date.FormatStyle(timeZone: calendar.timeZone).month(.abbreviated).day()
            style.locale = locale
            return date.formatted(style)
        }
        var steps = [TrialStep(
            icon: .unlock,
            title: String(localized: "Today"),
            detail: String(localized: "Check-ins, body map and photos — know your patterns over time and share a report with your doctor.")
        )]
        if let offset = reminderOffsetDays(trialDays: trialDays) {
            steps.append(TrialStep(
                icon: .reminder,
                title: title(offset),
                detail: canRemind
                    ? String(localized: "We'll remind you that your trial ends in \(reminderDaysBeforeEnd) days.")
                    : String(localized: "Your trial ends in \(reminderDaysBeforeEnd) days. Cancel anytime in Settings.")
            ))
        }
        steps.append(TrialStep(
            icon: .renewal,
            title: title(trialDays),
            detail: String(localized: "Your subscription starts. Cancel at least a day before to avoid being charged.")
        ))
        return steps
    }

    /// Same timeline shape for a plan without a trial: what happens today and on renewal.
    static func paidTimeline(for option: PaywallOption) -> [TrialStep] {
        [
            TrialStep(
                icon: .unlock,
                title: String(localized: "Today"),
                detail: String(localized: "Check-ins, body map and photos — know your patterns over time and share a report with your doctor.")
            ),
            TrialStep(
                icon: .renewal,
                title: option.plan == .weekly ? String(localized: "Every week") : String(localized: "Every year"),
                detail: String(localized: "\(option.displayPrice) renews automatically. Cancel anytime in Settings.")
            ),
        ]
    }

    /// Main price line under the plans, e.g. "7 days free, then $59.99/year".
    static func priceLine(for option: PaywallOption) -> String {
        let price = option.displayPrice
        return switch (option.plan, option.trialDays) {
        case (.yearly, let days?): String(localized: "\(days) days free, then \(price)/year")
        case (.weekly, let days?): String(localized: "\(days) days free, then \(price)/week")
        case (.yearly, nil): String(localized: "\(price)/year")
        case (.weekly, nil): String(localized: "\(price)/week")
        }
    }

    static func buttonTitle(for option: PaywallOption) -> String {
        option.trialDays.map { String(localized: "Start \($0)-day free trial") } ?? String(localized: "Continue")
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
