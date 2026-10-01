import SwiftUI

struct InsightsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insights")
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Patterns from your last 3 months")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.top, 12)

                    NavigationLink {
                        DoctorReportView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 44, height: 44)
                                .background(Theme.accentSoft.opacity(0.8), in: .circle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Report for your doctor")
                                    .font(.rounded(.headline, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text("One page · ready in a tap")
                                    .font(.rounded(.subheadline))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .glassCard(tint: Theme.accentSoft)
                    }
                    .buttonStyle(.plain)

                    SectionHeader(title: "Patterns we noticed", systemImage: "sparkle.magnifyingglass")
                    ForEach(store.insights) { insight in
                        insightCard(insight)
                    }
                    Text("Patterns aren't proof. They're a starting point to talk through with your doctor.")
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)

                    experimentCard
                    scoreCard
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenScaffold()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: insight.systemImage)
                .font(.title3)
                .foregroundStyle(Theme.sageDeep)
                .frame(width: 44, height: 44)
                .background(Theme.sageSoft, in: .circle)
            VStack(alignment: .leading, spacing: 8) {
                Text(insight.text)
                    .font(.rounded(.body, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    // Soft confidence meter (3 dots)
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Double(index) < insight.confidence * 3 ? Theme.accent : Theme.sand)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(insight.evidence)
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .glassCard()
    }

    private var experimentCard: some View {
        let experiment = store.experiment
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Experiment", systemImage: "flask")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("\(experiment.totalDays - experiment.day) days to go")
                    .font(.rounded(.caption, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text("\(experiment.title) · day \(experiment.day) of \(experiment.totalDays)")
                .font(.rounded(.title3, weight: .bold))
                .foregroundStyle(Theme.ink)
            ProgressView(value: Double(experiment.day), total: Double(experiment.totalDays))
                .tint(Theme.accent)
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .padding(.vertical, 4)
            Text(experiment.note)
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard()
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(
                    title: "Weekly \(store.scoreName)",
                    subtitle: store.condition == .psoriasis ? "Your weekly self-assessment" : "Patient-Oriented Eczema Measure, 0–28"
                )
                if let first = store.weeklyScores.first, let last = store.weeklyScores.last {
                    Text("\(Int(first.value)) → \(Int(last.value))")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.sageDeep)
                }
            }
            WeeklyScoreChart(data: store.weeklyScores)
        }
        .glassCard()
    }
}

#Preview {
    InsightsView()
        .previewSetup()
}
