import SwiftData
import SwiftUI

/// Subscription paywall: trial timeline, yearly / weekly plans (yearly preselected), purchase via RevenueCat.
/// `onClose == nil` hides the close button (hard paywall).
struct PaywallView: View {
    var onClose: (() -> Void)?
    var onSubscribed: () -> Void = {}

    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.modelContext) private var modelContext
    /// Two check-ins mean a diary from before (onboarding saves at most one): a lapsed subscriber
    /// can still take their data with them.
    @Query(PaywallView.diaryProbeDescriptor) private var diaryProbe: [DailyCheckIn]
    @State private var isExporting = false
    @State private var selected = PaywallPlan.preselected
    @State private var isPurchasing = false
    @State private var canRemind = false
    @State private var message: PaywallMessage?

    var body: some View {
        PaywallContent(
            options: subscriptions.options,
            loadState: subscriptions.loadState,
            canRemind: canRemind,
            isPurchasing: isPurchasing,
            selected: $selected,
            onContinue: buy,
            onRestore: restore,
            onRetry: { Task { await subscriptions.loadProducts() } },
            onClose: onClose,
            onExport: diaryProbe.count >= 2 ? { isExporting = true } : nil,
            onDebugSkip: debugSkip
        )
        .healthDataShare(isPresented: $isExporting) {
            try DataExport.writeCSV(from: modelContext)
        }
        .task {
            UsageStats.shared.record(.paywallShown)
            canRemind = await NotificationPermission.isAllowed()
            if subscriptions.loadState != .loaded { await subscriptions.loadProducts() }
        }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private static var diaryProbeDescriptor: FetchDescriptor<DailyCheckIn> {
        var descriptor = FetchDescriptor<DailyCheckIn>()
        descriptor.fetchLimit = 2
        return descriptor
    }

    private func buy() {
        guard subscriptions.canPurchase(selected), !isPurchasing else { return }
        let plan = selected
        let trialDays = subscriptions.options.first { $0.plan == plan }?.trialDays
        UsageStats.shared.record(.purchaseTapped(plan))
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(plan) {
                case .pending:
                    message = .pending
                case .cancelled:
                    break
                case .subscribed:
                    UsageStats.shared.record(.subscribed(plan, trial: trialDays != nil))
                    if let trialDays, let date = PaywallOffer.reminderDate(trialStart: .now, trialDays: trialDays) {
                        await NotificationService.scheduleTrialReminder(at: date)
                    }
                    onSubscribed()
                }
            } catch {
                message = .failed(error.localizedDescription)
            }
        }
    }

    private var debugSkip: (() -> Void)? {
        #if DEBUG
        return { subscriptions.skipPaywallForDebug() }
        #else
        return nil
        #endif
    }

    private func restore() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                try await subscriptions.restore()
                if subscriptions.isSubscribed { onSubscribed() } else { message = .nothingToRestore }
            } catch {
                message = .failed(error.localizedDescription)
            }
        }
    }
}

private struct PaywallMessage: Identifiable {
    let title: String
    let text: String
    var id: String { title + text }

    static let pending = PaywallMessage(title: String(localized: "Waiting for approval"),
                                        text: String(localized: "Your purchase needs approval. You'll get access as soon as it's approved."))
    static let nothingToRestore = PaywallMessage(title: String(localized: "No subscription found"),
                                                 text: String(localized: "We couldn't find an active Velvi subscription for this Apple Account."))
    static func failed(_ text: String) -> PaywallMessage { PaywallMessage(title: String(localized: "Purchase didn't go through"), text: text) }
}

enum PaywallLinks {
    /// Our terms; they include subscription terms and point to Apple's standard EULA.
    /// App Review requires both links on the paywall.
    static let terms = AppLinks.terms
    static let privacy = AppLinks.privacy
}
