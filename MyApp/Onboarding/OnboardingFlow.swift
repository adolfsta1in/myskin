import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, condition, profile, skinNow, goals, insight, bodyMap, treatments, notifications, location, sleep, privacy, plan

    var id: Int { rawValue }

    /// Optional steps show a "Skip" button.
    var isOptional: Bool {
        switch self {
        case .skinNow, .goals, .bodyMap, .treatments, .notifications, .location, .sleep, .privacy: true
        default: false
        }
    }

    /// Label used on the design canvas (O1…O12; notifications is part of O8).
    var label: String {
        switch self {
        case .welcome: "O1 · Welcome"
        case .condition: "O2 · Condition"
        case .profile: "O3 · Who for"
        case .skinNow: "O4 · Skin now"
        case .goals: "O5 · Goals"
        case .insight: "O6 · Insight"
        case .bodyMap: "O7 · Body map"
        case .treatments: "O8 · Treatments"
        case .notifications: "O8 · Notifications"
        case .location: "O9 · Location"
        case .sleep: "O10 · Sleep"
        case .privacy: "O11 · Privacy"
        case .plan: "O12 · Plan ready"
        }
    }
}

struct OnboardingFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var step: OnboardingStep
    @State private var isForward = true

    init(startAt step: OnboardingStep = .welcome) {
        _step = State(initialValue: step)
    }

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 0) {
                OnboardingTopBar(
                    progress: Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count),
                    canGoBack: step != .welcome,
                    showSkip: step.isOptional,
                    onBack: goBack,
                    onSkip: advance
                )
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .fontDesign(.rounded)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeStep(next: advance)
        case .condition: ConditionStep(next: advance)
        case .profile: ProfileStep(next: advance)
        case .skinNow: SkinNowStep(next: advance)
        case .goals: GoalsStep(next: advance)
        case .insight: DelayInsightStep(next: advance)
        case .bodyMap: FirstBodyMapStep(next: advance)
        case .treatments: TreatmentsStep(next: advance)
        case .notifications: NotificationsStep(next: advance)
        case .location: LocationStep(next: advance)
        case .sleep: SleepStep(next: advance)
        case .privacy: PrivacyStep(next: advance)
        case .plan: PlanReadyStep(next: advance)
        }
    }

    private func advance() {
        isForward = true
        withAnimation(.smooth(duration: 0.35)) {
            if let next = OnboardingStep(rawValue: step.rawValue + 1) {
                step = next
            } else {
                settings.hasCompletedOnboarding = true
                store.isLocked = false
            }
        }
    }

    private func goBack() {
        isForward = false
        withAnimation(.smooth(duration: 0.35)) {
            if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
                step = previous
            }
        }
    }
}

// MARK: - Top bar

struct OnboardingTopBar: View {
    let progress: Double
    let canGoBack: Bool
    let showSkip: Bool
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)
            .accessibilityLabel("Back")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.sand)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(geo.size.width * progress, 8))
                }
            }
            .frame(height: 6)
            .animation(.smooth, value: progress)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(progress * 100)) percent")

            Button("Skip", action: onSkip)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .buttonStyle(.plain)
                .frame(width: 44)
                .opacity(showSkip ? 1 : 0)
                .disabled(!showSkip)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Page scaffold

/// Common layout for onboarding pages: title, content, "why we ask", footer buttons.
struct OnboardingPage<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String?
    var why: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.rounded(.body))
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let why {
                            WhyWeAskText(text: why)
                                .padding(.top, 2)
                        }
                    }
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        // Footer stays above the home indicator; content scrolls beneath it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}

/// Large selectable card used for single-choice questions.
struct ChoiceCard: View {
    let title: String
    var subtitle: String?
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Theme.sageDeep)
                    .frame(width: 52, height: 52)
                    .background(isSelected ? Theme.accent : Theme.sageSoft, in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.sandDeep)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                isSelected ? .regular.tint(Theme.accentSoft.opacity(0.6)).interactive() : .regular.interactive(),
                in: .rect(cornerRadius: 24)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Buttons for soft permission screens.
struct PermissionButtons: View {
    var allowTitle: String = "Allow"
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        PrimaryButton(title: allowTitle, action: onAllow)
        Button("Not now", action: onNotNow)
            .font(.rounded(.headline, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .buttonStyle(.plain)
            .padding(.vertical, 6)
    }
}

#Preview {
    OnboardingFlow()
        .previewSetup(AppStore())
}
