import Observation
import RevenueCat
import StoreKit

/// Paywall products, purchases and access through RevenueCat (StoreKit 2 underneath).
/// RevenueCat gets the App Store transactions and an anonymous app user id — no diary data.
@Observable
final class Subscriptions {
    /// `unavailable`: RevenueCat answered but the current offering has none of our products
    /// (not set up in App Store Connect / the RevenueCat dashboard). `failed`: the request threw.
    enum LoadState: Equatable { case idle, loading, loaded, unavailable, failed }

    /// How a purchase ended, for the paywall.
    enum PurchaseOutcome { case subscribed, pending, cancelled }

    /// Public Apple SDK key from the RevenueCat dashboard (Project › API keys); it's meant to ship in the app.
    static let apiKey = "appl_zDqmbQdsEHQZPKSzvUkVJYUCKeH"
    /// Entitlement in the RevenueCat dashboard that both plans unlock — don't rename.
    static let entitlementID = "Velvi"

    private(set) var options: [PaywallOption] = []
    private(set) var loadState: LoadState = .idle
    /// Active (or in-trial, or in a billing grace period) subscription, per RevenueCat.
    private(set) var isSubscribed = false
    /// False until entitlements were checked once — don't show a paywall before that.
    private(set) var hasCheckedEntitlements = false
    /// The active subscription, for Settings; nil without one.
    private(set) var current: CurrentSubscription?

    #if DEBUG
    /// Debug builds only: skip the paywall (testing on a phone with a real diary).
    var debugBypass = UserDefaults.standard.bool(forKey: Subscriptions.debugSkipKey)

    /// Kept across launches: iOS often ends the app in the background, and the paywall
    /// came back on the next launch. Reinstalling the app shows the paywall again.
    static let debugSkipKey = "debugSkipPaywall"

    /// Debug builds only: show the paywall even with a subscription or a skip (this session).
    var debugForcesPaywall = false

    func skipPaywallForDebug() {
        debugForcesPaywall = false
        debugBypass = true
        UserDefaults.standard.set(true, forKey: Self.debugSkipKey)
    }

    func showPaywallForDebug() {
        debugBypass = false
        UserDefaults.standard.removeObject(forKey: Self.debugSkipKey)
        debugForcesPaywall = true
    }
    #endif

    /// Whether the app may open past the paywall.
    var hasAccess: Bool {
        #if DEBUG
        if debugForcesPaywall { return false }
        if debugBypass { return true }
        #endif
        return isSubscribed
    }

    @ObservationIgnored private var packages: [PaywallPlan: Package] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Configures RevenueCat once and follows customer info: renewals, refunds, purchases made elsewhere.
    func start() {
        guard updatesTask == nil else { return }
        Self.configureIfNeeded()
        updatesTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task { await refreshEntitlements() }
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        Self.configureIfNeeded()
        loadState = .loading
        do {
            let offering = try await Purchases.shared.offerings().current
            var byPlan: [PaywallPlan: Package] = [:]
            var result: [PaywallOption] = []
            for package in offering?.availablePackages ?? [] {
                guard let plan = PaywallPlan(productID: package.storeProduct.productIdentifier),
                      let product = package.storeProduct.sk2Product else { continue }
                byPlan[plan] = package
                result.append(PaywallOption(
                    plan: plan,
                    displayPrice: product.displayPrice,
                    price: product.price,
                    priceFormat: product.priceFormatStyle,
                    trialDays: await Self.eligibleTrialDays(product)
                ))
            }
            packages = byPlan
            options = result.sorted { lhs, rhs in
                PaywallPlan.allCases.firstIndex(of: lhs.plan) ?? 0 < PaywallPlan.allCases.firstIndex(of: rhs.plan) ?? 0
            }
            loadState = result.isEmpty ? .unavailable : .loaded
        } catch {
            loadState = .failed
        }
    }

    func canPurchase(_ plan: PaywallPlan) -> Bool { packages[plan] != nil }

    /// Buys the plan through RevenueCat (Apple's purchase sheet). Throws if the purchase failed.
    func purchase(_ plan: PaywallPlan) async throws -> PurchaseOutcome {
        guard let package = packages[plan] else { return .cancelled }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            #if DEBUG
            debugForcesPaywall = false
            #endif
            apply(result.customerInfo)
            return isSubscribed ? .subscribed : .pending
        } catch ErrorCode.paymentPendingError {
            return .pending
        } catch ErrorCode.purchaseCancelledError {
            return .cancelled
        }
    }

    /// "Restore purchases": syncs with the App Store (may ask the user to sign in).
    func restore() async throws {
        Self.configureIfNeeded()
        let info = try await Purchases.shared.restorePurchases()
        #if DEBUG
        debugForcesPaywall = false
        #endif
        apply(info)
    }

    func refreshEntitlements() async {
        Self.configureIfNeeded()
        do {
            apply(try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent))
        } catch {
            // Offline: RevenueCat's cached info is still the best answer.
            if let cached = try? await Purchases.shared.customerInfo(fetchPolicy: .fromCacheOnly) {
                apply(cached)
            } else {
                hasCheckedEntitlements = true
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements.active[Self.entitlementID]
        current = entitlement.flatMap { entitlement in
            PaywallPlan(productID: entitlement.productIdentifier).map { plan in
                CurrentSubscription(
                    plan: plan,
                    periodEnd: entitlement.expirationDate,
                    willRenew: entitlement.willRenew,
                    isTrial: entitlement.periodType == .trial,
                    // In a billing grace period Apple is still collecting payment and access continues.
                    hasBillingIssue: entitlement.billingIssueDetectedAt != nil
                )
            }
        }
        isSubscribed = entitlement != nil
        hasCheckedEntitlements = true
    }

    private static func configureIfNeeded() {
        guard !Purchases.isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Free-trial days from the introductory offer, if this Apple account can still get it.
    private static func eligibleTrialDays(_ product: Product) async -> Int? {
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await subscription.isEligibleForIntroOffer else { return nil }
        let unit: PaywallOffer.TrialPeriodUnit = switch offer.period.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .day
        }
        return PaywallOffer.trialDays(periodValue: offer.period.value * offer.periodCount, unit: unit)
    }
}

/// What Settings shows about the active subscription.
struct CurrentSubscription: Equatable {
    let plan: PaywallPlan
    /// When the current period (or the billing grace period) ends.
    let periodEnd: Date?
    let willRenew: Bool
    let isTrial: Bool
    /// Payment failed; Apple keeps retrying and access continues for now.
    let hasBillingIssue: Bool

    /// e.g. «Yearly · free trial», «Weekly».
    var title: String {
        let name = plan == .yearly ? String(localized: "Yearly") : String(localized: "Weekly")
        return isTrial ? String(localized: "\(name) · free trial") : name
    }

    /// e.g. «Renews on Oct 24, 2026», «Ends on Oct 24, 2026».
    var detail: String? {
        if hasBillingIssue { return String(localized: "There's a problem with your payment. Update it in Settings › Apple Account to keep access.") }
        guard let periodEnd else { return nil }
        let date = periodEnd.formatted(date: .abbreviated, time: .omitted)
        if isTrial { return willRenew ? String(localized: "Trial ends on \(date), then your subscription starts") : String(localized: "Trial ends on \(date) and won't renew") }
        return willRenew ? String(localized: "Renews on \(date)") : String(localized: "Ends on \(date) and won't renew")
    }
}
