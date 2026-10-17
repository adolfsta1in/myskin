import Foundation

/// Anonymous usage counts (step 63): which onboarding steps people reach or skip, and how the paywall does.
/// No identifier and no diary content — only the event name, an optional fixed detail (step or plan name),
/// app version and language. Each event is sent at most once per install, so the server only counts.
/// Names and details are stable: the server accepts only these, and past counts are grouped by them.
nonisolated enum UsageEvent: Hashable, Sendable {
    case onboardingStep(String)
    case onboardingSkipped(String)
    case onboardingCompleted
    case paywallShown
    case purchaseTapped(PaywallPlan)
    case subscribed(PaywallPlan, trial: Bool)

    var name: String {
        switch self {
        case .onboardingStep: "onboarding_step"
        case .onboardingSkipped: "onboarding_skip"
        case .onboardingCompleted: "onboarding_done"
        case .paywallShown: "paywall_shown"
        case .purchaseTapped: "purchase_tap"
        case .subscribed: "subscribed"
        }
    }

    var detail: String? {
        switch self {
        case .onboardingStep(let step), .onboardingSkipped(let step): step
        case .onboardingCompleted, .paywallShown: nil
        case .purchaseTapped(let plan): plan.rawValue
        case .subscribed(let plan, let trial): trial ? "\(plan.rawValue)_trial" : plan.rawValue
        }
    }

    /// Marks the event as sent for this install.
    var onceKey: String {
        detail.map { "\(name).\($0)" } ?? name
    }
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
