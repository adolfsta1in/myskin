import SwiftData
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, disclaimer, aboutYou, psoriasisProfile, skinNow, goals, insight, bodyMap, joints, treatments, firstCheckIn, notifications, privacy, plan, commitment

    var id: Int { rawValue }

    /// Optional steps show a "Skip" button. The disclaimer can never be skipped.
    var isOptional: Bool {
        switch self {
        case .aboutYou, .psoriasisProfile, .joints, .skinNow, .goals, .bodyMap, .treatments, .firstCheckIn, .notifications, .privacy, .commitment: true
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
        case .skinNow: "skinNow"
        case .goals: "goals"
        case .insight: "insight"
        case .bodyMap: "bodyMap"
        case .joints: "joints"
        case .treatments: "treatments"
        case .firstCheckIn: "firstCheckIn"
        case .notifications: "notifications"
        case .privacy: "privacy"
        case .plan: "plan"
        case .commitment: "commitment"
        }
    }

    /// Label used on the design canvas.
    var label: String {
        switch self {
        case .welcome: "O1 · Welcome"
        case .disclaimer: "O2 · Disclaimer"
        case .aboutYou: "O3 · About you"
        case .psoriasisProfile: "O4 · Your psoriasis"
        case .skinNow: "O5 · Skin now"
        case .goals: "O6 · Goals"
        case .insight: "O7 · Insight"
        case .bodyMap: "O8 · Body map"
        case .joints: "O9 · Joints"
        case .treatments: "O10 · Treatments"
        case .firstCheckIn: "O10b · First check-in"
        case .notifications: "O11 · Notifications"
        case .privacy: "O12 · Privacy"
        case .plan: "O13 · Plan ready"
        case .commitment: "O14 · Commitment"
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
    /// Velvi's one-off state: a mood that overrides the step's, a line in a bubble, the reaction to play.
    @State private var velviMood: VelviMood?
    @State private var velviLine: VelviLine?
    @State private var velviMotion: VelviMotion = .hop
    @State private var velviTrigger = 0

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
                    .environment(\.onboardingVelvi, velvi)
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
        .onChange(of: step) { old, new in velviEnter(new, from: old) }
        // Velvi nods at each answer.
        .onChange(of: draft.hasAcceptedDisclaimer) { _, accepted in if accepted { velviReact(.nod) } }
        .onChange(of: draft.sex) { velviReact(.nod) }
        .onChange(of: draft.psoriasisTypes) { velviReact(.nod) }
        .onChange(of: draft.goals) { velviReact(.nod) }
        .onChange(of: draft.arthritis) { velviReact(.nod) }
        .task(id: velviLine) {
            guard velviLine != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) {
                velviLine = nil
                velviMood = nil
            }
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
        case .skinNow: SkinNowStep(next: advance)
        case .goals: GoalsStep(next: advance)
        case .insight: DelayInsightStep(next: advance)
        case .bodyMap: FirstBodyMapStep(next: advance)
        case .joints: JointsStep(next: advance)
        case .treatments: TreatmentsStep(next: advance)
        case .firstCheckIn: FirstCheckInStep(next: advance)
        case .notifications: NotificationsStep(next: advance)
        case .privacy: PrivacyStep(next: advance)
        case .plan: PlanReadyStep(next: advance)
        case .commitment: CommitmentStep(onCommitted: commit)
        }
    }

    // MARK: Velvi

    /// What the page draws for Velvi: next to the title, or large above it on welcome and plan.
    private var velvi: OnboardingVelvi? {
        guard let entry = VelviReaction.onboarding(step) else { return nil }
        var cue = entry.cue
        cue.mood = velviMood ?? liveMood ?? cue.mood
        cue.motion = velviMotion
        cue.line = velviLine
        return OnboardingVelvi(cue: cue, presence: entry.presence, trigger: velviTrigger)
    }

    /// Steps where Velvi follows a slider as it moves.
    private var liveMood: VelviMood? {
        switch step {
        case .skinNow: VelviReaction.skinNow(draft.skinNow)
        case .firstCheckIn: VelviReaction.firstCheckIn(itch: draft.firstCheckIn.itch)
        default: nil
        }
    }

    private func velviReact(_ motion: VelviMotion) {
        velviMotion = motion
        velviTrigger += 1
    }

    /// «Hold to commit»: Velvi celebrates, then onboarding ends and the paywall comes.
    private func commit() {
        let cue = VelviReaction.committed
        velviMood = cue.mood
        velviLine = cue.line
        velviReact(cue.motion)
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            advance()
        }
    }

    private func velviEnter(_ step: OnboardingStep, from previous: OnboardingStep) {
        velviMood = nil
        velviLine = nil
        // Right after «Save my first entry»: Velvi answers the entry on the next screen.
        if step == .notifications, previous == .firstCheckIn, draft.hasFirstCheckIn {
            let entry = draft.firstCheckIn
            let cue = VelviReaction.afterCheckIn(itch: entry.itch, mode: entry.newSpots ? .flare : .calm)
            velviMood = cue.mood
            velviLine = cue.line
            velviReact(cue.motion)
        } else if let cue = VelviReaction.onboarding(step)?.cue {
            velviReact(cue.motion)
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

    @Environment(\.onboardingVelvi) private var velvi
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Velvi beside the title; above it when the text is very large and needs the width.
    private var titleLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let velvi, velvi.presence == .hero {
                            OnboardingVelviView(velvi: velvi, size: 150)
                                .frame(maxWidth: .infinity)
                        }
                        titleLayout {
                            Text(title)
                                .font(.rounded(.largeTitle, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let velvi, velvi.presence == .companion {
                                OnboardingVelviView(velvi: velvi, size: 64)
                            }
                        }
                        if let line = velvi?.cue.line {
                            VelviBubble(line.text, tail: .topTrailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .transition(.scale(scale: 0.6, anchor: .topTrailing).combined(with: .opacity))
                        }
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
                .animation(.spring(duration: 0.4, bounce: 0.3), value: velvi?.cue.line)
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

// MARK: - Velvi

/// Velvi as the onboarding page should draw it; set by `OnboardingFlow` for the current step.
struct OnboardingVelvi: Equatable {
    var cue: VelviCue
    var presence: VelviPresence
    /// Changes when Velvi should play `cue.motion` (an answer, a saved entry).
    var trigger: Int
}

extension EnvironmentValues {
    @Entry var onboardingVelvi: OnboardingVelvi?
}

struct OnboardingVelviView: View {
    let velvi: OnboardingVelvi
    let size: CGFloat

    var body: some View {
        VelviMascot(mood: velvi.cue.mood, prop: velvi.cue.prop, size: size, motion: velvi.cue.motion, trigger: velvi.trigger)
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

#Preview("Velvi as companion") {
    OnboardingFlow(startAt: .goals)
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}

#Preview("Commitment") {
    OnboardingFlow(startAt: .commitment)
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
#endif
