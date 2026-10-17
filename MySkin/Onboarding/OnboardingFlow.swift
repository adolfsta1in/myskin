import SwiftData
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, disclaimer, aboutYou, psoriasisProfile, joints, skinNow, goals, insight, bodyMap, treatments, firstCheckIn, notifications, privacy, plan

    var id: Int { rawValue }

    /// Optional steps show a "Skip" button. The disclaimer can never be skipped.
    var isOptional: Bool {
        switch self {
        case .aboutYou, .psoriasisProfile, .joints, .skinNow, .goals, .bodyMap, .treatments, .firstCheckIn, .notifications, .privacy: true
        default: false
        }
    }

    /// Name in anonymous usage counts (`UsageEvent`). Never rename: past counts are grouped by it.
    var usageName: String {
        switch self {
        case .welcome: "welcome"
        case .disclaimer: "disclaimer"
        case .aboutYou: "aboutYou"
        case .psoriasisProfile: "psoriasisProfile"
        case .joints: "joints"
        case .skinNow: "skinNow"
        case .goals: "goals"
        case .insight: "insight"
        case .bodyMap: "bodyMap"
        case .treatments: "treatments"
        case .firstCheckIn: "firstCheckIn"
        case .notifications: "notifications"
        case .privacy: "privacy"
        case .plan: "plan"
        }
    }

    /// Label used on the design canvas.
    var label: String {
        switch self {
        case .welcome: "O1 · Welcome"
        case .disclaimer: "O2 · Disclaimer"
        case .aboutYou: "O3 · About you"
        case .psoriasisProfile: "O4 · Your psoriasis"
        case .joints: "O5 · Joints"
        case .skinNow: "O6 · Skin now"
        case .goals: "O7 · Goals"
        case .insight: "O8 · Insight"
        case .bodyMap: "O9 · Body map"
        case .treatments: "O10 · Treatments"
        case .firstCheckIn: "O10b · First check-in"
        case .notifications: "O11 · Notifications"
        case .privacy: "O12 · Privacy"
        case .plan: "O13 · Plan ready"
        }
    }
}

struct OnboardingFlow: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var step: OnboardingStep
    @State private var isForward = true
    @State private var draft = OnboardingDraft()
    @State private var saveError: String?

    init(startAt step: OnboardingStep = .welcome) {
        _step = State(initialValue: step)
    }

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 0) {
                OnboardingTopBar(
                    progress: Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count),
                    // Welcome sells the result; the long questionnaire shows up from the next screen.
                    showsProgress: step != .welcome,
                    canGoBack: step != .welcome,
                    showSkip: step.isOptional,
                    onBack: goBack,
                    onSkip: skip
                )
                content
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: isForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .environment(draft)
        .fontDesign(.rounded)
        // Which steps people reach: once per install, no answers.
        .onChange(of: step, initial: true) { _, step in
            UsageStats.shared.record(.onboardingStep(step.usageName))
        }
        .alert("Couldn't save your answers", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeStep(next: advance)
        case .disclaimer: DisclaimerStep(next: advance)
        case .aboutYou: AboutYouStep(next: advance)
        case .psoriasisProfile: PsoriasisProfileStep(next: advance)
        case .joints: JointsStep(next: advance)
        case .skinNow: SkinNowStep(next: advance)
        case .goals: GoalsStep(next: advance)
        case .insight: DelayInsightStep(next: advance)
        case .bodyMap: FirstBodyMapStep(next: advance)
        case .treatments: TreatmentsStep(next: advance)
        case .firstCheckIn: FirstCheckInStep(next: advance)
        case .notifications: NotificationsStep(next: advance)
        case .privacy: PrivacyStep(next: advance)
        case .plan: PlanReadyStep(next: advance)
        }
    }

    private func advance() {
        // The disclaimer has to be accepted; Skip is hidden there, this guards the rest.
        if step == .disclaimer && !draft.hasAcceptedDisclaimer { return }
        isForward = true
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            withAnimation(.smooth(duration: 0.35)) { step = next }
        } else {
            finish()
        }
    }

    private func skip() {
        UsageStats.shared.record(.onboardingSkipped(step.usageName))
        advance()
    }

    /// Saves the answers, then leaves onboarding.
    private func finish() {
        do {
            try draft.save(in: modelContext)
            UsageStats.shared.record(.onboardingCompleted)
            withAnimation(.smooth(duration: 0.35)) {
                settings.hasCompletedOnboarding = true
            }
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
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
    var showsProgress = true
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
            .opacity(showsProgress ? 1 : 0)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(progress * 100)) percent")
            .accessibilityHidden(!showsProgress)

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
    var allowTitle: String = String(localized: "Allow")
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

#if DEBUG
#Preview {
    OnboardingFlow()
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
#endif
