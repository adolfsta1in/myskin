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
            Text("Hold the button to make the promise.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
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

/// Fills while held; when full, it locks and calls `onCommitted` once.
/// VoiceOver: a plain activation commits (holding is hard to do there).
struct HoldToCommitButton: View {
    let onCommitted: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var isDone = false

    static let holdDuration = 1.5

    var body: some View {
        ZStack {
            Capsule().fill(Theme.accent)
            GeometryReader { proxy in
                Capsule()
                    .fill(Theme.sageDeep)
                    .frame(width: max(proxy.size.height, proxy.size.width * progress))
                    .opacity(progress > 0 ? 1 : 0)
            }
            Label {
                Text(isDone ? "Committed" : "Hold to commit")
            } icon: {
                Image(systemName: isDone ? "checkmark" : "hand.point.up.left.fill")
            }
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.opacity)
        }
        .frame(height: 56)
        .clipShape(Capsule())
        .scaleEffect(isPressing && !isDone ? 0.97 : 1)
        .animation(.spring(duration: 0.25), value: isPressing)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 50) {
            commit()
        } onPressingChanged: { pressing in
            guard !isDone else { return }
            isPressing = pressing
            if pressing {
                withAnimation(.linear(duration: Self.holdDuration)) { progress = 1 }
            } else {
                withAnimation(.spring(duration: 0.3)) { progress = 0 }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPressing) { _, pressing in pressing }
        .sensoryFeedback(.success, trigger: isDone)
        .disabled(isDone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isDone ? "Committed" : "Hold to commit"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
    }

    private func commit() {
        guard !isDone else { return }
        withAnimation(.smooth(duration: 0.2)) {
            progress = 1
            isDone = true
            isPressing = false
        }
        onCommitted()
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
