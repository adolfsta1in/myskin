import Foundation

/// Anonymous usage counts (steps 63, 63.3): which onboarding steps people reach or skip, how the paywall does,
/// and whether the app is opened again after setup. No identifier and no diary content — only the event name,
/// an optional fixed detail (step, plan or result name), app version and language. Each event is sent at most
/// once per install, so the server only counts. Names and details are stable: the server accepts only these,
/// and past counts are grouped by them. A new name needs the Worker on the site updated first.
nonisolated enum UsageEvent: Hashable, Sendable {
    case onboardingStep(String)
    case onboardingSkipped(String)
    case onboardingCompleted
    case paywallShown
    /// The paywall couldn't show plans.
    case paywallUnavailable(PaywallLoadProblem)
    /// The user picked a plan other than the preselected one, or went back to it.
    case planSelected(PaywallPlan)
    case purchaseTapped(PaywallPlan)
    case purchaseCancelled(PaywallPlan)
    /// Waiting for approval (Ask to Buy), or the store didn't confirm access yet.
    case purchasePending(PaywallPlan)
    case purchaseFailed(PaywallPlan)
    case subscribed(PaywallPlan, trial: Bool)
    /// «Restore purchases» on the paywall and what came of it.
    case restored(RestoreResult)
    /// The app was opened again at least this many days after setup (`UsagePolicy.returnDays`).
    case returned(days: Int)

    var name: String {
        switch self {
        case .onboardingStep: "onboarding_step"
        case .onboardingSkipped: "onboarding_skip"
        case .onboardingCompleted: "onboarding_done"
        case .paywallShown: "paywall_shown"
        case .paywallUnavailable: "paywall_unavailable"
        case .planSelected: "plan_selected"
        case .purchaseTapped: "purchase_tap"
        case .purchaseCancelled: "purchase_cancel"
        case .purchasePending: "purchase_pending"
        case .purchaseFailed: "purchase_failed"
        case .subscribed: "subscribed"
        case .restored: "restore"
        case .returned: "returned"
        }
    }

    var detail: String? {
        switch self {
        case .onboardingStep(let step), .onboardingSkipped(let step): step
        case .onboardingCompleted, .paywallShown: nil
        case .paywallUnavailable(let problem): problem.rawValue
        case .planSelected(let plan), .purchaseTapped(let plan), .purchaseCancelled(let plan),
             .purchasePending(let plan), .purchaseFailed(let plan): plan.rawValue
        case .subscribed(let plan, let trial): trial ? "\(plan.rawValue)_trial" : plan.rawValue
        case .restored(let result): result.rawValue
        case .returned(let days): "d\(days)"
        }
    }

    /// Marks the event as sent for this install.
    var onceKey: String {
        detail.map { "\(name).\($0)" } ?? name
    }
}

/// Why the paywall had no plans. rawValues go to the server — don't rename.
nonisolated enum PaywallLoadProblem: String, Sendable {
    /// The store answered without our products.
    case unavailable
    /// The request failed (offline, server error).
    case failed
}

/// Result of «Restore purchases». rawValues go to the server — don't rename.
nonisolated enum RestoreResult: String, Sendable {
    case found
    /// rawValue "none"; a case named `none` would clash with `Optional.none`.
    case nothing = "none"
    case failed
}

/// One event as it goes over the wire. Nothing else is sent: no id, no time (the server keeps only the day).
nonisolated struct UsageRecord: Codable, Equatable, Sendable {
    let event: String
    let detail: String?
    let app: String
    let lang: String
    let build: String

    init(_ event: UsageEvent, app: String, lang: String, build: String) {
        self.event = event.name
        self.detail = event.detail
        self.app = app
        self.lang = lang
        self.build = build
    }
}

nonisolated enum UsagePolicy {
    /// Payload format the server checks.
    static let schema = 1
    /// Events waiting while offline; older ones are dropped beyond this.
    static let maxPending = 50
    /// Events per request (the server rejects bigger batches).
    static let maxBatch = 20

    /// «Opened again after setup» milestones, in days.
    static let returnDays = [1, 7, 30]

    static func shouldRecord(_ event: UsageEvent, isEnabled: Bool, sent: Set<String>) -> Bool {
        isEnabled && !sent.contains(event.onceKey)
    }

    static func enqueue(_ record: UsageRecord, into pending: [UsageRecord]) -> [UsageRecord] {
        Array((pending + [record]).suffix(maxPending))
    }

    /// Request body: `{"v":1,"events":[…]}`.
    static func body(for records: [UsageRecord]) throws -> Data {
        struct Body: Encodable {
            let v: Int
            let events: [UsageRecord]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(Body(v: schema, events: records))
    }

    /// Milestones reached by `now`: whole calendar days since the day setup was finished.
    static func returns(completedAt: Date, now: Date, calendar: Calendar = .current) -> [UsageEvent] {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: completedAt), to: calendar.startOfDay(for: now)).day ?? 0
        return returnDays.filter { days >= $0 }.map { UsageEvent.returned(days: $0) }
    }

    /// The server turned the batch down (unknown event, bad format): sending it again won't help.
    /// 408 and 429 are worth another try, like network errors and 5xx.
    static func isRejected(statusCode: Int) -> Bool {
        (400..<500).contains(statusCode) && statusCode != 408 && statusCode != 429
    }

    /// The language the app shows, as the server groups it.
    static func language(_ identifier: String?) -> String {
        guard let identifier else { return "other" }
        if identifier.hasPrefix("pt") { return "pt-BR" }
        if identifier.hasPrefix("es") { return "es-419" }
        if identifier.hasPrefix("de") { return "de" }
        if identifier.hasPrefix("en") { return "en" }
        return "other"
    }
}
