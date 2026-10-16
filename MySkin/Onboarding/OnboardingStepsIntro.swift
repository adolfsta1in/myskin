import SwiftUI

// MARK: - O1 Welcome

struct WelcomeStep: View {
    let next: () -> Void

    private let promises: [(String, String)] = [
        ("magnifyingglass", "Log itch, flares and possible triggers"),
        ("chart.xyaxis.line", "See how your skin changes with treatment"),
        ("doc.text", "Arrive at your doctor with a ready report"),
    ]

    var body: some View {
        OnboardingPage(title: "Understand your skin") {
            VStack(alignment: .leading, spacing: 24) {
                Image("WelcomeHero")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                GlassEffectContainer(spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(promises.indices, id: \.self) { index in
                        let (symbol, text) = promises[index]
                        HStack(spacing: 14) {
                            Image(systemName: symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 40, height: 40)
                                .glassEffect(.regular, in: .circle)
                            Text(text)
                                .font(.rounded(.body, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                }
            }
        } footer: {
            PrimaryButton(title: "Get started", action: next)
            Label("No account needed. Your diary stays in the app on this phone.", systemImage: "lock.fill")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - O2 Disclaimer

/// Must be accepted before going on: the app is a diary, not a medical device.
struct DisclaimerStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let next: () -> Void

    private let points: [(String, String)] = [
        ("book.closed", "MySkin is a diary. It helps you notice patterns and talk to your doctor."),
        ("stethoscope", "It does not diagnose, and it does not prescribe or change treatment."),
        ("exclamationmark.triangle", "If something worries you — or you feel very unwell — contact your doctor or emergency services."),
    ]

    var body: some View {
        @Bindable var draft = draft
        OnboardingPage(title: "Before we start") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(points.indices, id: \.self) { index in
                        let (symbol, text) = points[index]
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 28)
                            Text(text)
                                .font(.rounded(.body))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .glassCard()

                Toggle(isOn: $draft.hasAcceptedDisclaimer) {
                    Text("I understand that MySkin is not medical advice")
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.accent)
                .glassCard()
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
                .disabled(!draft.hasAcceptedDisclaimer)
        }
    }
}

// MARK: - O3 About you

struct AboutYouStep: View {
    @Environment(OnboardingDraft.self) private var draft
    @FocusState private var isNameFocused: Bool
    let next: () -> Void

    var body: some View {
        @Bindable var draft = draft
        OnboardingPage(
            title: "A little about you",
            subtitle: "All optional.",
            why: "Your name is only for the greeting. Age and sex help your doctor read the report."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                TextField("Your first name", text: $draft.name)
                    .font(.rounded(.body))
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .glassCard(padding: 14)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sex")
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    GlassEffectContainer(spacing: 10) {
                        FlowLayout(spacing: 10) {
                            ForEach(Sex.allCases) { sex in
                                TagChip(title: sex.title, isSelected: draft.sex == sex) {
                                    withAnimation(.snappy) { draft.sex = draft.sex == sex ? nil : sex }
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("Age")
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Picker("Age", selection: $draft.age) {
                        Text("Not set").tag(Int?.none)
                        ForEach(ProfileInfo.ages, id: \.self) { age in
                            Text(String(age)).tag(Optional(age))
                        }
                    }
                    .tint(Theme.accent)
                }
                .glassCard(padding: 14)
            }
        } footer: {
            // Hidden while typing so the keyboard doesn't push it over the fields.
            if !isNameFocused {
                PrimaryButton(title: "Continue", action: next)
            }
        }
    }
}

// MARK: - O4 Your psoriasis

struct PsoriasisProfileStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let next: () -> Void

    var body: some View {
        @Bindable var draft = draft
        OnboardingPage(
            title: "Tell us about your psoriasis",
            subtitle: "Pick every form you have, if you know. It's fine to skip.",
            why: "Some forms — scalp, nails, folds, palms — matter more for your doctor than their size suggests."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                GlassEffectContainer(spacing: 10) {
                    FlowLayout(spacing: 10) {
                        ForEach(PsoriasisType.allCases) { type in
                            TagChip(title: type.title, systemImage: type.systemImage, isSelected: draft.psoriasisTypes.contains(type)) {
                                withAnimation(.snappy) {
                                    if draft.psoriasisTypes.contains(type) { draft.psoriasisTypes.remove(type) } else { draft.psoriasisTypes.insert(type) }
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("When did it start?")
                        .font(.rounded(.body, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Picker("Year it started", selection: $draft.onsetYear) {
                        Text("Not sure").tag(Int?.none)
                        ForEach(OnboardingDraft.onsetYears(), id: \.self) { year in
                            Text(String(year)).tag(Optional(year))
                        }
                    }
                    .tint(Theme.accent)
                }
                .glassCard(padding: 14)
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }
}

// MARK: - O5 Joints

/// Psoriatic arthritis. People who already know answer here; the others get the joint check card on Today.
struct JointsStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let next: () -> Void

    private func systemImage(_ status: ArthritisStatus) -> String {
        switch status {
        case .diagnosed: "stethoscope"
        case .suspected: "figure.walk"
        case .no: "checkmark.seal"
        case .unsure: "questionmark.circle"
        }
    }

    var body: some View {
        OnboardingPage(
            title: "Do you have psoriatic arthritis?",
            subtitle: "Joint pain, swelling or morning stiffness can be part of psoriasis.",
            why: "If you're not sure, the app will offer a short joint check after setup."
        ) {
            VStack(spacing: 12) {
                ForEach(ArthritisStatus.allCases) { status in
                    ChoiceCard(
                        title: status.title,
                        systemImage: systemImage(status),
                        isSelected: draft.arthritis == status
                    ) {
                        withAnimation(.snappy) { draft.arthritis = draft.arthritis == status ? nil : status }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }
}

// MARK: - O6 Skin now

struct SkinNowStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let next: () -> Void

    private var label: String {
        switch draft.skinNow {
        case ..<0.2: "Almost clear"
        case ..<0.4: "Mild"
        case ..<0.6: "Moderate"
        case ..<0.8: "Noticeable flare"
        default: "Severe flare"
        }
    }

    var body: some View {
        @Bindable var draft = draft
        OnboardingPage(
            title: "How is your skin right now?",
            why: "This becomes your baseline, so progress is measured from where you are today."
        ) {
            VStack(spacing: 24) {
                SkinMoodIllustration(level: draft.skinNow)
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                Text(label)
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: label)
                VStack(spacing: 6) {
                    Slider(value: $draft.skinNow, in: 0...1)
                        .tint(Theme.accent)
                    HStack {
                        Text("Almost clear")
                        Spacer()
                        Text("Severe flare")
                    }
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
                }
            }
            .glassCard()
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }
}

/// Illustrated elbow whose plaques grow with the level: neighbouring stages cross-fade as the slider moves.
struct SkinMoodIllustration: View {
    let level: Double

    private static let stages = 5

    var body: some View {
        let position = min(max(level, 0), 1) * Double(Self.stages - 1)
        let lower = min(Int(position), Self.stages - 2)
        let fraction = position - Double(lower)
        ZStack {
            Image("SkinLevel\(lower)")
                .resizable()
                .scaledToFill()
            Image("SkinLevel\(lower + 1)")
                .resizable()
                .scaledToFill()
                .opacity(fraction)
        }
        .frame(width: 210, height: 210)
        .clipShape(.circle)
        .overlay(Circle().stroke(Theme.sandDeep.opacity(0.6), lineWidth: 1))
        .background(Circle().fill(Theme.sageSoft).padding(-8))
        .accessibilityHidden(true)
    }
}

// MARK: - O7 Goals

struct GoalsStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "What matters most to you?",
            subtitle: "Pick as many as you like.",
            why: "It helps you remember why you're keeping the diary — and what to bring to your doctor."
        ) {
            GlassEffectContainer(spacing: 10) {
                FlowLayout(spacing: 10) {
                    ForEach(Goal.allCases) { goal in
                        TagChip(title: goal.title, systemImage: goal.systemImage, isSelected: draft.goals.contains(goal)) {
                            withAnimation(.snappy) {
                                if draft.goals.contains(goal) { draft.goals.remove(goal) } else { draft.goals.insert(goal) }
                            }
                        }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
        }
    }
}

// MARK: - O8 Delay insight

struct DelayInsightStep: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "Flares can show up days or weeks after a trigger",
            subtitle: "That's why links are hard to spot on your own. A short daily note helps you and your doctor see patterns."
        ) {
            VStack(spacing: 20) {
                HStack(spacing: 0) {
                    timelineNode("bolt", "Trigger", "Stress, infection, skin injury, cold dry air", Theme.accentSoft)
                    dashedGap
                    timelineNode("hourglass", "Pause", "Days to a few weeks", Theme.sand)
                    dashedGap
                    timelineNode("flame", "Flare", "New patches, itch", Theme.intensityMild)
                }
                .padding(.vertical, 12)
                Text("Logging a few seconds a day makes these delayed links easier to notice.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .glassCard()
        } footer: {
            PrimaryButton(title: "Got it", action: next)
        }
    }

    private var dashedGap: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 2)
            .overlay(
                Line()
                    .stroke(Theme.sandDeep, style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            )
            .frame(maxWidth: .infinity)
            .offset(y: -22)
    }

    private func timelineNode(_ symbol: String, _ title: String, _ detail: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.ink)
                .frame(width: 52, height: 52)
                .background(color, in: .circle)
            Text(title)
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.rounded(.caption2))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}

nonisolated private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
