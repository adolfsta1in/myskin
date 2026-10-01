import SwiftUI

// MARK: - O1 Welcome

struct WelcomeStep: View {
    let next: () -> Void

    private let promises: [(String, String)] = [
        ("magnifyingglass", "Find what triggers your flares"),
        ("chart.xyaxis.line", "See if your treatment is working"),
        ("doc.text", "Arrive at your doctor with a ready report"),
    ]

    var body: some View {
        OnboardingPage(title: "Understand your skin") {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    ZStack {
                        SoftIllustration(systemImage: "leaf", size: 200)
                        Image(systemName: "sparkle")
                            .font(.title)
                            .foregroundStyle(Theme.accent)
                            .offset(x: 70, y: -70)
                        Circle()
                            .fill(Theme.accentSoft)
                            .frame(width: 36, height: 36)
                            .offset(x: -80, y: 60)
                    }
                    Spacer()
                }
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
            Label("Photos and data stay only on your phone", systemImage: "lock.fill")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - O2 Condition

struct ConditionStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "What are you dealing with?",
            why: "So we can show the score your dermatologist understands."
        ) {
            VStack(spacing: 12) {
                ForEach(Condition.allCases) { condition in
                    ChoiceCard(
                        title: condition.title,
                        subtitle: condition.subtitle,
                        systemImage: condition.systemImage,
                        isSelected: store.condition == condition
                    ) {
                        withAnimation(.snappy) { store.condition = condition }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
                .disabled(store.condition == nil)
        }
    }
}

// MARK: - O3 Profile

struct ProfileStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "Who is this diary for?",
            why: "Children's skin is tracked with age-appropriate wording and scales."
        ) {
            VStack(spacing: 12) {
                ChoiceCard(title: "For me", subtitle: "Track your own skin", systemImage: "person", isSelected: store.profile == .myself) {
                    withAnimation(.snappy) { store.profile = .myself }
                }
                ChoiceCard(title: "For my child", subtitle: "You'll fill it in together", systemImage: "figure.and.child.holdinghands", isSelected: store.profile == .child) {
                    withAnimation(.snappy) { store.profile = .child }
                }
                Label("You can add more profiles later — for example, one for each child.", systemImage: "person.2")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 4)
            }
        } footer: {
            PrimaryButton(title: "Continue", action: next)
                .disabled(store.profile == nil)
        }
    }
}

// MARK: - O4 Skin now

struct SkinNowStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    private var label: String {
        switch store.skinNow {
        case ..<0.2: "Almost clear"
        case ..<0.4: "Mild"
        case ..<0.6: "Moderate"
        case ..<0.8: "Noticeable flare"
        default: "Severe flare"
        }
    }

    var body: some View {
        @Bindable var store = store
        OnboardingPage(
            title: "How is your skin right now?",
            why: "This becomes your baseline, so progress is measured from where you are today."
        ) {
            VStack(spacing: 24) {
                SkinMoodIllustration(level: store.skinNow)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                Text(label)
                    .font(.rounded(.title2, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: label)
                VStack(spacing: 6) {
                    Slider(value: $store.skinNow, in: 0...1)
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

/// Soft abstract illustration that becomes busier as the level grows.
struct SkinMoodIllustration: View {
    let level: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.sageSoft.opacity(1 - level * 0.6))
                .frame(width: 200, height: 200)
            Circle()
                .fill(Theme.sand)
                .frame(width: 150, height: 150)
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6 * 2 * .pi
                Circle()
                    .fill(Theme.intensity(value: level * 10).opacity(0.75))
                    .frame(width: 18 + level * 26, height: 18 + level * 26)
                    .offset(x: cos(angle) * 44, y: sin(angle) * 44)
                    .opacity(Double(index) < level * 7 ? 1 : 0)
            }
            Image(systemName: level < 0.3 ? "leaf" : "circle.hexagongrid")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.sageDeep)
        }
        .animation(.smooth, value: level)
        .accessibilityHidden(true)
    }
}

// MARK: - O5 Goals

struct GoalsStep: View {
    @Environment(AppStore.self) private var store
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "What matters most to you?",
            subtitle: "Pick as many as you like.",
            why: "We'll arrange your Today screen around what you care about."
        ) {
            GlassEffectContainer(spacing: 10) {
                FlowLayout(spacing: 10) {
                    ForEach(Goal.allCases) { goal in
                        TagChip(title: goal.title, systemImage: goal.systemImage, isSelected: store.goals.contains(goal)) {
                            withAnimation(.snappy) {
                                if store.goals.contains(goal) { store.goals.remove(goal) } else { store.goals.insert(goal) }
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

// MARK: - O6 Delay insight

struct DelayInsightStep: View {
    let next: () -> Void

    var body: some View {
        OnboardingPage(
            title: "Flares often show up a few days after a trigger",
            subtitle: "That's why they're so hard to spot on your own. MySkin connects the dots for you."
        ) {
            VStack(spacing: 20) {
                HStack(spacing: 0) {
                    timelineNode("bolt", "Trigger", "Stress, poor sleep, dry air", Theme.accentSoft)
                    dashedGap
                    timelineNode("hourglass", "Pause", "2–7 days", Theme.sand)
                    dashedGap
                    timelineNode("flame", "Flare", "Itch, redness", Theme.intensityMild)
                }
                .padding(.vertical, 12)
                Text("Logging a few seconds a day is enough to reveal these delayed links.")
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

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
