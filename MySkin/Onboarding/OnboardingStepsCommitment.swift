import SwiftUI

// MARK: - O14 Commitment

/// Last step before the paywall: a small promise to yourself, sealed by holding a button.
/// A commitment you make yourself is one you're more likely to keep. Nothing is saved — it's only a moment.
struct CommitmentStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let onCommitted: () -> Void

    private var title: String {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? String(localized: "Make it a habit") : String(localized: "Make it a habit, \(name)")
    }

    var body: some View {
        OnboardingPage(
            title: title,
            subtitle: String(localized: "Psoriasis changes slowly. A few seconds a day is what makes the changes visible — to you and your doctor.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("I commit to:")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                promise("checkmark.circle.fill", String(localized: "A quick check-in every day — about 20 seconds"))
                promise("checkmark.circle.fill", String(localized: "Noting what could matter: triggers, food, sleep"))
                promise("checkmark.circle.fill", String(localized: "Bringing my report to my next doctor's visit"))
            }
            .glassCard()
        } footer: {
            HoldToCommitButton(onCommitted: onCommitted)
                .frame(maxWidth: .infinity)
        }
    }

    private func promise(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.sageDeep)
            Text(text)
                .font(.rounded(.body, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A round fingerprint button: while held it fills from the bottom, grows and hums with
/// haptic ticks that get faster and stronger; when full it locks and calls `onCommitted` once.
/// VoiceOver: a plain activation commits (holding is hard to do there).
struct HoldToCommitButton: View {
    let onCommitted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var isDone = false
    @State private var tick = 0
    @State private var tickIntensity = 0.3

    static let holdDuration = 1.6
    private let size: CGFloat = 112

    var body: some View {
        VStack(spacing: 12) {
            button
            Text(isDone ? "Committed" : "Hold to commit")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(isDone ? Theme.sageDeep : Theme.inkSoft)
                .contentTransition(.opacity)
                .animation(.smooth, value: isDone)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isDone ? "Committed" : "Hold to commit"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
    }

    private var button: some View {
        ZStack {
            Circle().fill(Theme.accentSoft)
            fingerprint(color: Theme.accent)
            // The filled part rises from the bottom and turns the fingerprint white as it goes.
            ZStack {
                Circle().fill(Theme.accent)
                fingerprint(color: .white)
            }
            .mask(alignment: .bottom) {
                Rectangle().frame(height: size * progress)
            }
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.sageDeep, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(-9)
        }
        .frame(width: size, height: size)
        .scaleEffect(reduceMotion ? 1 : 1 + 0.16 * progress)
        .shadow(color: Theme.accent.opacity(0.25 + 0.25 * progress), radius: 8 + 14 * progress, y: 4)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 60) {
            commit()
        } onPressingChanged: { pressing in
            guard !isDone else { return }
            isPressing = pressing
            if pressing {
                withAnimation(.linear(duration: Self.holdDuration)) { progress = 1 }
            } else {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { progress = 0 }
            }
        }
        // A hum while held: ticks get closer together and stronger as the circle fills.
        .task(id: isPressing) {
            guard isPressing else { return }
            let start = Date.now
            while !Task.isCancelled, isPressing, !isDone {
                let share = min(Date.now.timeIntervalSince(start) / Self.holdDuration, 1)
                tickIntensity = 0.35 + 0.65 * share
                tick += 1
                try? await Task.sleep(for: .milliseconds(Int(120 - 75 * share)))
            }
        }
        .sensoryFeedback(trigger: tick) { _, _ in .impact(weight: .medium, intensity: tickIntensity) }
        .sensoryFeedback(.success, trigger: isDone)
        .disabled(isDone)
    }

    private func fingerprint(color: Color) -> some View {
        Image(systemName: isDone ? "checkmark" : "touchid")
            .font(.system(size: size * 0.46, weight: .regular))
            .foregroundStyle(color)
            .contentTransition(.symbolEffect(.replace))
    }

    private func commit() {
        guard !isDone else { return }
        isPressing = false
        withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
            progress = 1
            isDone = true
        }
        onCommitted()
    }
}

/// The soft «Welcome to Velvi» between the commitment and the paywall.
struct WelcomeToVelviView: View {
    @State private var showsText = false
    @State private var hop = 0

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 20) {
                let cue = VelviReaction.committed
                VelviMascot(mood: cue.mood, size: 200, motion: cue.motion, trigger: hop)
                VStack(spacing: 8) {
                    Text("Welcome to Velvi")
                        .font(.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Your diary starts today.")
                        .font(.rounded(.title3))
                        .foregroundStyle(Theme.inkSoft)
                }
                .multilineTextAlignment(.center)
                .opacity(showsText ? 1 : 0)
                .offset(y: showsText ? 0 : 12)
            }
            .padding(.horizontal, 32)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.35))
            hop += 1
            withAnimation(.smooth(duration: 0.8)) { showsText = true }
        }
    }
}

#if DEBUG
#Preview("Commitment step") {
    let draft = OnboardingDraft()
    draft.name = "Alex"
    return CommitmentStep(onCommitted: {})
        .environment(draft)
        .background(WarmBackground())
        .previewSetup()
}
#endif

#if DEBUG
#Preview("Welcome to Velvi") {
    WelcomeToVelviView()
        .previewSetup()
}
#endif
