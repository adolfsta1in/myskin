import SwiftUI

/// The first real check-in, saved as today's entry when onboarding finishes — so the user
/// has started their diary before the paywall.
struct FirstCheckInStep: View {
    @Environment(OnboardingDraft.self) private var draft
    let next: () -> Void

    var body: some View {
        @Bindable var draft = draft
        OnboardingPage(
            title: String(localized: "Your first check-in"),
            subtitle: String(localized: "This is your daily routine — about 20 seconds. It's saved as today's entry in your diary.")
        ) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Itch today")
                            .font(.rounded(.subheadline, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(draft.firstCheckIn.itch)")
                            .font(.rounded(.title2, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("· \(draft.firstCheckIn.itchDescription)")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Slider(
                        value: Binding(get: { Double(draft.firstCheckIn.itch) }, set: { draft.firstCheckIn.itch = Int($0) }),
                        in: 0...10,
                        step: 1
                    ) {
                        Text("Itch")
                    } minimumValueLabel: {
                        Text("0").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                    } maximumValueLabel: {
                        Text("10").font(.rounded(.caption)).foregroundStyle(Theme.inkSoft)
                    }
                    .tint(Theme.accent)
                    .sensoryFeedback(.selection, trigger: draft.firstCheckIn.itch)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything that could matter today?")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    FlowLayout {
                        ForEach(Trigger.allCases) { trigger in
                            TagChip(
                                title: trigger.title,
                                systemImage: trigger.systemImage,
                                isSelected: draft.firstCheckIn.triggers.contains(trigger)
                            ) {
                                if draft.firstCheckIn.triggers.contains(trigger) {
                                    draft.firstCheckIn.triggers.remove(trigger)
                                } else {
                                    draft.firstCheckIn.triggers.insert(trigger)
                                }
                            }
                        }
                    }
                }

                Toggle(isOn: $draft.firstCheckIn.newSpots) {
                    Text("New spots appeared")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.accent)
            }
            .glassCard()

            Text("Day by day these entries build your trends — and the report you can show your doctor.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        } footer: {
            PrimaryButton(title: "Save my first entry") {
                draft.hasFirstCheckIn = true
                next()
            }
        }
    }
}

/// Plan-step card after the first check-in: what the doctor report will look like, with today's entry as day 1.
/// Only the first bar is real; the rest are empty slots, so it never shows invented data.
struct ReportPreviewCard: View {
    let itch: Int

    private static let days = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(Theme.accent)
                Text("Your doctor report")
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Day 1")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Theme.sageDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.sageSoft, in: .capsule)
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<Self.days, id: \.self) { day in
                    if day == 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.intensity(value: Double(itch)))
                            .frame(height: max(8, CGFloat(itch) / 10 * 64))
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Theme.sandDeep.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .frame(height: 64)
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)
            .accessibilityHidden(true)
            Text("Itch \(itch)/10 today. After a few weeks of check-ins this becomes your itch trend, triggers and treatment summary — a PDF to share with your doctor.")
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(tint: Theme.accentSoft)
    }
}

#Preview("First check-in step") {
    FirstCheckInStep(next: {})
        .environment(OnboardingDraft())
        .background(WarmBackground())
        .previewSetup()
}

#Preview("Plan with report preview") {
    let draft = OnboardingDraft()
    draft.firstCheckIn.itch = 5
    draft.hasFirstCheckIn = true
    return PlanReadyStep(next: {})
        .environment(draft)
        .background(WarmBackground())
        .previewSetup()
}
