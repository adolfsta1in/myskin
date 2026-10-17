import Foundation
import Testing
@testable import MySkin

struct UsageEventTests {
    /// The server accepts only these and groups past counts by them — don't change.
    @Test func namesAndDetailsAreStable() {
        #expect(UsageEvent.onboardingStep("bodyMap").name == "onboarding_step")
        #expect(UsageEvent.onboardingStep("bodyMap").detail == "bodyMap")
        #expect(UsageEvent.onboardingSkipped("goals").name == "onboarding_skip")
        #expect(UsageEvent.onboardingCompleted.name == "onboarding_done")
        #expect(UsageEvent.onboardingCompleted.detail == nil)
        #expect(UsageEvent.paywallShown.name == "paywall_shown")
        #expect(UsageEvent.purchaseTapped(.weekly).detail == "weekly")
        #expect(UsageEvent.subscribed(.yearly, trial: true).detail == "yearly_trial")
        #expect(UsageEvent.subscribed(.yearly, trial: false).detail == "yearly")
    }

    @Test func stepNamesAreStableAndUnique() {
        let names = OnboardingStep.allCases.map(\.usageName)
        #expect(names == ["welcome", "disclaimer", "aboutYou", "psoriasisProfile", "skinNow", "goals",
                          "insight", "bodyMap", "joints", "treatments", "firstCheckIn", "notifications", "privacy", "plan"])
    }

    @Test func onceKeysSeparateDetails() {
        #expect(UsageEvent.onboardingStep("goals").onceKey != UsageEvent.onboardingSkipped("goals").onceKey)
        #expect(UsageEvent.onboardingStep("goals").onceKey != UsageEvent.onboardingStep("joints").onceKey)
    }

    /// Only these fields go out: no id, no time, nothing from the diary.
    @Test func bodyCarriesOnlyFixedFields() throws {
        let record = UsageRecord(.onboardingStep("joints"), app: "1.0", lang: "de", build: "release")
        let json = try #require(try JSONSerialization.jsonObject(with: UsagePolicy.body(for: [record])) as? [String: Any])
        #expect(Set(json.keys) == ["v", "events"])
        #expect(json["v"] as? Int == 1)
        let event = try #require((json["events"] as? [[String: Any]])?.first)
        #expect(Set(event.keys) == ["event", "detail", "app", "lang", "build"])
    }

    @Test func languageGroups() {
        #expect(UsagePolicy.language("pt-BR") == "pt-BR")
        #expect(UsagePolicy.language("es-419") == "es-419")
        #expect(UsagePolicy.language("de") == "de")
        #expect(UsagePolicy.language("en") == "en")
        #expect(UsagePolicy.language("fr") == "other")
        #expect(UsagePolicy.language(nil) == "other")
    }

    @Test func pendingIsCapped() {
        let record = UsageRecord(.paywallShown, app: "1.0", lang: "en", build: "release")
        var pending: [UsageRecord] = []
        for _ in 0..<(UsagePolicy.maxPending + 5) { pending = UsagePolicy.enqueue(record, into: pending) }
        #expect(pending.count == UsagePolicy.maxPending)
    }
}

struct UsageStatsTests {
    private actor Outbox {
        var bodies: [Data] = []
        var fails = false
        func add(_ body: Data) throws {
            if fails { throw URLError(.notConnectedToInternet) }
            bodies.append(body)
        }
        func setFails(_ value: Bool) { fails = value }
        func eventCount() -> Int {
            bodies.compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .compactMap { $0["events"] as? [Any] }
                .reduce(0) { $0 + $1.count }
        }
    }

    private func makeDefaults() -> UserDefaults? {
        let suite = "MySkinTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)
        defaults?.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeStats(_ defaults: UserDefaults, _ outbox: Outbox) -> UsageStats {
        UsageStats(endpoint: URL(string: "https://example.invalid/v1/usage"), defaults: defaults) { _, body in
            try await outbox.add(body)
        }
    }

    @Test func eachEventIsSentOncePerInstall() async throws {
        let defaults = try #require(makeDefaults())
        let outbox = Outbox()
        let stats = makeStats(defaults, outbox)
        stats.record(.onboardingStep("welcome"))
        stats.record(.onboardingStep("welcome"))
        await stats.flush()
        // A relaunch doesn't count the same step again.
        let relaunched = makeStats(defaults, outbox)
        relaunched.record(.onboardingStep("welcome"))
        await relaunched.flush()
        #expect(await outbox.eventCount() == 1)
        #expect(relaunched.pending.isEmpty)
    }

    @Test func offlineEventsWaitForTheNextFlush() async throws {
        let defaults = try #require(makeDefaults())
        let outbox = Outbox()
        await outbox.setFails(true)
        let stats = makeStats(defaults, outbox)
        stats.record(.paywallShown)
        await stats.flush()
        #expect(stats.pending.count == 1)
        await outbox.setFails(false)
        await stats.flush()
        #expect(stats.pending.isEmpty)
        #expect(await outbox.eventCount() == 1)
    }

    @Test func switchedOffSendsNothing() async throws {
        let defaults = try #require(makeDefaults())
        let settings = AppSettings(defaults: defaults)
        #expect(settings.shareUsageStats)
        settings.shareUsageStats = false
        let outbox = Outbox()
        let stats = makeStats(defaults, outbox)
        stats.record(.onboardingCompleted)
        await stats.flush()
        #expect(stats.pending.isEmpty)
        #expect(stats.sent.isEmpty)
        #expect(await outbox.eventCount() == 0)
    }

    @Test func noEndpointRecordsNothing() throws {
        let defaults = try #require(makeDefaults())
        let stats = UsageStats(endpoint: nil, defaults: defaults) { _, _ in }
        stats.record(.paywallShown)
        #expect(stats.sent.isEmpty)
        #expect(stats.pending.isEmpty)
    }

    @Test func resetForgetsSentEvents() async throws {
        let defaults = try #require(makeDefaults())
        let outbox = Outbox()
        let stats = makeStats(defaults, outbox)
        stats.record(.paywallShown)
        await stats.flush()
        stats.reset()
        #expect(stats.sent.isEmpty)
    }

    @Test func endpointIsOnOurSite() {
        #expect(AppLinks.usageStats?.absoluteString == "https://myskin.cc/v1/usage")
    }
}
