import SwiftData
import SwiftUI

/// Trends over the last 3 months (itch, affected area, DLQI) and links to the report and questionnaires.
struct InsightsView: View {
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]
    @Query private var results: [QuestionnaireResult]

    var body: some View {
        let start = Trends.periodStart(endingOn: .now)
        let itch = Trends.weeklyItch(checkIns: checkIns.map(\.sample), from: start, to: .now)
        let bsa = Trends.bsaHistory(zones: assessments.map(\.datedScore), from: start, to: .now)
        let dlqi = Trends.scores(.dlqi, results: results.map(\.trendPoint), from: start, to: .now)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Insights")
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Trends from your last 3 months")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.top, 12)

                    NavigationLink {
                        DoctorReportView()
                    } label: {
                        LinkCard(systemImage: "doc.text", title: "Report for your doctor", subtitle: "One page · ready in a tap", tint: Theme.accentSoft)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        QuestionnaireHistoryView()
                    } label: {
                        LinkCard(systemImage: "list.clipboard", title: "Questionnaires", subtitle: "DLQI and PEST · scores over time")
                    }
                    .buttonStyle(.plain)

                    TrendCard(
                        title: "Itch",
                        subtitle: "Weekly average, 0–10",
                        data: itch,
                        scale: .itch,
                        format: { $0.formatted(.number.precision(.fractionLength(1))) },
                        emptyText: "Check in daily and your itch trend will appear here."
                    )
                    TrendCard(
                        title: "Affected area",
                        subtitle: "Share of body surface, from the body map",
                        data: bsa,
                        scale: .bsa,
                        format: { "\($0.formatted(.number.precision(.fractionLength(0...1)))) %" },
                        emptyText: "Assess your skin on the Body tab to see how the affected area changes."
                    )
                    TrendCard(
                        title: "Quality of life (DLQI)",
                        subtitle: "0 = no effect, 30 = extremely large effect",
                        data: dlqi,
                        scale: .dlqi,
                        format: { "\(Int($0))" },
                        emptyText: "Take the DLQI questionnaire monthly to see its trend here."
                    )

                    Text("Trends aren't a diagnosis. They're a starting point to talk through with your doctor.")
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenScaffold()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct LinkCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var tint: Color?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accentSoft.opacity(0.8), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.inkSoft)
        }
        .glassCard(tint: tint)
    }
}

/// One trend: first → latest value and a chart, or an empty state.
private struct TrendCard: View {
    let title: String
    let subtitle: String
    let data: [DayValue]
    let scale: ScoreScale
    let format: (Double) -> String
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: title, subtitle: subtitle)
                if let first = data.first, let last = data.last, data.count > 1 {
                    Text("\(format(first.value)) → \(format(last.value))")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Theme.sageDeep)
                }
            }
            if data.count > 1 {
                ScoreTrendChart(data: data, scale: scale)
            } else if let only = data.first {
                Text("One entry so far: \(format(only.value)) on \(only.date.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text(emptyText)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard()
    }
}

#Preview {
    InsightsView()
        .previewSetup()
}

#Preview("Empty") {
    InsightsView()
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
