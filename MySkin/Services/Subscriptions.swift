import Observation
import StoreKit

/// StoreKit 2: paywall products, purchases and whether the user has an active subscription.
/// Apple does the billing and receipts; nothing is sent anywhere else.
@Observable
final class Subscriptions {
    /// `unavailable`: the App Store answered but has none of our products (not set up in
    /// App Store Connect, or a run without the local `.storekit` file). `failed`: the request threw.
    enum LoadState: Equatable { case idle, loading, loaded, unavailable, failed }

    private(set) var options: [PaywallOption] = []
    private(set) var loadState: LoadState = .idle
    /// Active (or in-trial) subscription, verified by StoreKit.
    private(set) var isSubscribed = false
    /// False until entitlements were checked once — don't show a paywall before that.
    private(set) var hasCheckedEntitlements = false
    /// The active subscription, for Settings; nil without one.
    private(set) var current: CurrentSubscription?

    #if DEBUG
    /// Debug builds only: skip the paywall for this session (testing on a phone with a real diary).
    var debugBypass = false
    #endif

    /// Whether the app may open past the paywall.
    var hasAccess: Bool {
        #if DEBUG
        if debugBypass { return true }
        #endif
        return isSubscribed
    }

    @ObservationIgnored private var products: [PaywallPlan: Product] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Listens for renewals, refunds and purchases made elsewhere; checks current entitlements.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements() }
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: PaywallPlan.allCases.map(\.productID))
            var byPlan: [PaywallPlan: Product] = [:]
            var result: [PaywallOption] = []
            for product in loaded {
                guard let plan = PaywallPlan(productID: product.id) else { continue }
                byPlan[plan] = product
                result.append(PaywallOption(
                    plan: plan,
                    displayPrice: product.displayPrice,
                    price: product.price,
                    priceFormat: product.priceFormatStyle,
                    trialDays: await Self.eligibleTrialDays(product)
                ))
            }
            products = byPlan
            options = result.sorted { lhs, rhs in
                PaywallPlan.allCases.firstIndex(of: lhs.plan) ?? 0 < PaywallPlan.allCases.firstIndex(of: rhs.plan) ?? 0
            }
            loadState = result.isEmpty ? .unavailable : .loaded
        } catch {
            loadState = .failed
        }
    }

    func product(for plan: PaywallPlan) -> Product? { products[plan] }

    /// Handles the result of `PurchaseAction`. True if the subscription is now active.
    func complete(_ result: Product.PurchaseResult) async -> Bool {
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            await refreshEntitlements()
            return isSubscribed
        case .success(.unverified), .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    /// "Restore purchases": syncs with the App Store (may ask the user to sign in).
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var found: CurrentSubscription?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  let plan = PaywallPlan(productID: transaction.productID),
                  transaction.revocationDate == nil else { continue }
            let status = await transaction.subscriptionStatus
            if let expiration = transaction.expirationDate, expiration < .now {
                // In a billing grace period the last period has ended, but Apple is still
                // collecting payment and the subscriber keeps full access.
                guard status?.state == .inGracePeriod else { continue }
            }
            var renewal: Product.SubscriptionInfo.RenewalInfo?
            if case .verified(let info) = status?.renewalInfo { renewal = info }
            found = CurrentSubscription(
                plan: plan,
                periodEnd: renewal?.gracePeriodExpirationDate ?? transaction.expirationDate,
                willRenew: renewal?.willAutoRenew ?? true,
                isTrial: transaction.offer?.paymentMode == .freeTrial,
                hasBillingIssue: status?.state == .inGracePeriod
            )
        }
        current = found
        isSubscribed = found != nil
        hasCheckedEntitlements = true
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
        let name = plan == .yearly ? "Yearly" : "Weekly"
        return isTrial ? "\(name) · free trial" : name
    }

    /// e.g. «Renews on Oct 24, 2026», «Ends on Oct 24, 2026».
    var detail: String? {
        if hasBillingIssue { return "There's a problem with your payment. Update it in Settings › Apple Account to keep access." }
        guard let periodEnd else { return nil }
        let date = periodEnd.formatted(date: .abbreviated, time: .omitted)
        if isTrial { return willRenew ? "Trial ends on \(date), then your subscription starts" : "Trial ends on \(date) and won't renew" }
        return willRenew ? "Renews on \(date)" : "Ends on \(date) and won't renew"
    }
}
