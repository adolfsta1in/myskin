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
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  PaywallPlan(productID: transaction.productID) != nil,
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            active = true
        }
        isSubscribed = active
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
