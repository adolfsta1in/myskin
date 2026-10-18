import SwiftUI

// MARK: - Content

/// Layout only, so previews and the canvas can show it without StoreKit.
struct PaywallContent: View {
    let options: [PaywallOption]
    var loadState: Subscriptions.LoadState = .loaded
    var canRemind = true
    var isPurchasing = false
    @Binding var selected: PaywallPlan
    var onContinue: () -> Void = {}
    var onRestore: () -> Void = {}
    var onRetry: () -> Void = {}
    var onClose: (() -> Void)?
    /// Shown when there's a diary from before: the data stays the user's even without a subscription.
    var onExport: (() -> Void)?
    /// Debug builds pass a closure: shows «Skip paywall (debug build)».
    var onDebugSkip: (() -> Void)?

    @State private var showsSafety = false
    @State private var velviMotion: VelviMotion = .wave
    @State private var velviTrigger = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var current: PaywallOption? {
        options.first { $0.plan == selected } ?? options.first
    }

    private var savings: Int? {
        guard let yearly = options.first(where: { $0.plan == .yearly }),
              let weekly = options.first(where: { $0.plan == .weekly }) else { return nil }
        return PaywallOffer.savingsPercent(yearly: yearly.price, weekly: weekly.price)
    }

    private var steps: [TrialStep] {
        guard let current else { return PaywallOffer.trialTimeline(trialDays: 7, canRemind: canRemind) }
        if let days = current.trialDays { return PaywallOffer.trialTimeline(trialDays: days, canRemind: canRemind) }
        return PaywallOffer.paidTimeline(for: current)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                TrialTimelineCard(steps: steps)
                    .padding(.top, -64)
                plans
                Label("Payment handled by Apple", systemImage: "checkmark.shield")
                    .font(.rounded(.footnote, weight: .medium))
                    .foregroundStyle(Theme.sageDeep)
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { footer }
        .screenScaffold()
        .animation(.smooth(duration: 0.25), value: selected)
        .onChange(of: selected) { velviReact(.nod) }
        // Red flags must stay visible even without a subscription.
        .fullScreenCover(isPresented: $showsSafety) {
            RedFlagView(flags: RedFlag.allCases)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(current?.trialDays == nil ? "Velvi Premium" : "Let's get started")
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                closeButton
            }
            .frame(minHeight: 36)
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(current?.trialDays == nil ? "Get full access to your diary" : "How your free trial works")
                        .font(.rounded(.title, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        ForEach([String(localized: "No tracking"), String(localized: "Cancel anytime")], id: \.self) { item in
                            Label(item, systemImage: "checkmark")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.rounded(.footnote, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // With very large text the title needs the whole width.
                if !dynamicTypeSize.isAccessibilitySize {
                    VelviMascot(mood: .happy, prop: .star, size: 92, motion: velviMotion, trigger: velviTrigger)
                        .onAppear { velviTrigger += 1 }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 76)
        .background(alignment: .bottom) {
            LinearGradient(colors: [Theme.accent, Theme.sageDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                .padding(.horizontal, -Theme.screenPadding)
                .padding(.top, -600)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        if let onClose {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Close")
        }
    }

    private func velviReact(_ motion: VelviMotion) {
        velviMotion = motion
        velviTrigger += 1
    }

    // MARK: Plans

    @ViewBuilder
    private var plans: some View {
        if options.isEmpty {
            VStack(spacing: 10) {
                switch loadState {
                case .idle, .loading:
                    ProgressView()
                    Text("Loading plans…")
                case .unavailable, .loaded:
                    Text("Subscriptions aren't available right now. Please try again later.")
                        .multilineTextAlignment(.center)
                    Button("Try again", action: onRetry)
                        .buttonStyle(.glass)
                case .failed:
                    Text("Couldn't load subscription options. Check your connection and try again.")
                        .multilineTextAlignment(.center)
                    Button("Try again", action: onRetry)
                        .buttonStyle(.glass)
                }
                if let onDebugSkip {
                    Button("Skip paywall (debug build)", action: onDebugSkip)
                        .font(.rounded(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.flare)
                        .padding(.top, 6)
                }
            }
            .font(.rounded(.subheadline))
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            HStack(spacing: 12) {
                ForEach(options) { option in
                    PlanCard(
                        option: option,
                        badge: option.plan == .yearly ? savings.map { String(localized: "SAVE \($0)%") } : nil,
                        isSelected: option.plan == current?.plan
                    ) {
                        selected = option.plan
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var priceSummary: some View {
        if let current {
            VStack(spacing: 4) {
                Text(PaywallOffer.priceLine(for: current))
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            priceSummary
            PrimaryButton(title: current.map(PaywallOffer.buttonTitle) ?? String(localized: "Continue")) {
                velviReact(.hop)
                onContinue()
            }
                .disabled(current == nil || isPurchasing)
                .overlay {
                    if isPurchasing { ProgressView().tint(.white) }
                }
            HStack(spacing: 18) {
                Button("Restore purchases", action: onRestore)
                    .disabled(isPurchasing)
                if let terms = PaywallLinks.terms { Link("Terms", destination: terms) }
                if let privacy = PaywallLinks.privacy { Link("Privacy", destination: privacy) }
                Button("Urgent symptoms?") { showsSafety = true }
            }
            .font(.rounded(.footnote, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            Text("Renews automatically. Cancel anytime in Settings › Apple Account.")
                .font(.rounded(.caption2))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            if let onExport {
                Button("Your diary is still on this iPhone · Export it", action: onExport)
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 14)
        .background {
            Theme.cream
                .ignoresSafeArea()
                .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: -4)
        }
    }
}

// MARK: - Timeline

private struct TrialTimelineCard: View {
    let steps: [TrialStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                TimelineRow(step: step, isFirst: index == 0, isLast: index == steps.count - 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cream, in: .rect(cornerRadius: Theme.cardRadius))
        .shadow(color: Theme.ink.opacity(0.08), radius: 18, y: 8)
        .contentTransition(.opacity)
    }
}

private struct TimelineRow: View {
    let step: TrialStep
    let isFirst: Bool
    let isLast: Bool

    private var symbol: String {
        switch step.icon {
        case .unlock: "lock.open.fill"
        case .reminder: "bell.fill"
        case .renewal: "star.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .frame(maxHeight: .infinity, alignment: .top)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: isFirst ? 16 : 0,
                        bottomLeadingRadius: isLast ? 16 : 0,
                        bottomTrailingRadius: isLast ? 16 : 0,
                        topTrailingRadius: isFirst ? 16 : 0
                    )
                    .fill(isLast
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.accent, Theme.accentSoft.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Theme.accent))
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(step.detail)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 5)
            .padding(.bottom, isLast ? 4 : 16)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let option: PaywallOption
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    private var title: String { option.plan == .yearly ? String(localized: "Yearly") : String(localized: "Weekly") }
    private var period: String { option.plan == .yearly ? "/yr" : "/wk" }
    private var subtitle: String {
        switch option.plan {
        case .yearly: String(localized: "\(option.formatted(PaywallOffer.weeklyEquivalent(ofYearly: option.price))) a week")
        case .weekly: String(localized: "Billed weekly")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.rounded(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Theme.accent : Theme.sandDeep)
                }
                Text("\(Text(option.displayPrice).font(.rounded(.title2, weight: .bold)))\(Text(period).font(.rounded(.subheadline)))")
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
                Text(option.trialDays.map { String(localized: "\($0)-day free trial") } ?? String(localized: "No free trial"))
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(option.trialDays == nil ? Theme.inkSoft : Theme.sageDeep)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(isSelected ? Theme.cream : Theme.cream.opacity(0.55), in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isSelected ? Theme.accent : Theme.sand, lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.sageDeep, in: .capsule)
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview("Paywall · yearly") {
    PaywallContent(options: PreviewData.paywallOptions, selected: .constant(.yearly))
        .previewSetup()
}
#endif
