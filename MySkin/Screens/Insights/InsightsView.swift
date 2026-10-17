import SwiftData
import SwiftUI

/// Trends over the last 3 months (itch, affected area, skin impact), patterns from the diary,
/// and links to the report and questionnaires.
struct InsightsView: View {
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]
    @Query private var results: [QuestionnaireResult]

    var body: some View {
        let start = Trends.periodStart(endingOn: .now)
        let itch = Trends.weeklyItch(checkIns: checkIns.map(\.sample), from: start, to: .now)
        let bsa = Trends.bsaHistory(zones: assessments.datedScores, from: start, to: .now)
        let skinImpact = Trends.scores(.skinImpact, results: results.map(\.trendPoint), from: start, to: .now)

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
                        LinkCard(systemImage: "doc.text", title: String(localized: "Report for your doctor"), subtitle: String(localized: "One page · ready in a tap"), tint: Theme.accentSoft)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DiaryCalendarView()
                    } label: {
                        LinkCard(systemImage: "calendar", title: String(localized: "Diary calendar"), subtitle: String(localized: "What happened on each day, with photos"))
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        QuestionnaireHistoryView()
                    } label: {
                        LinkCard(systemImage: "list.clipboard", title: String(localized: "Questionnaires"), subtitle: String(localized: "Skin impact and joint check · scores over time"))
                    }
                    .buttonStyle(.plain)

                    PatternsCard()

                    TrendCard(
                        title: String(localized: "Itch"),
                        subtitle: String(localized: "Weekly average, 0–10"),
                        data: itch,
                        scale: .itch,
                        format: { $0.formatted(.number.precision(.fractionLength(1))) },
                        pointDate: { String(localized: "week of \($0.formatted(date: .abbreviated, time: .omitted))") },
                        emptyText: String(localized: "Check in daily and your itch trend will appear here.")
                    )
                    TrendCard(
                        title: String(localized: "Affected area"),
                        subtitle: String(localized: "Share of body surface, from the body map"),
                        data: bsa,
                        scale: .bsa,
                        format: { "\($0.formatted(.number.precision(.fractionLength(0...1)))) %" },
                        emptyText: String(localized: "Assess your skin on the Body tab to see how the affected area changes.")
                    )
                    TrendCard(
                        title: String(localized: "Skin impact"),
                        subtitle: String(localized: "How much your skin got in the way, 0–18"),
                        data: skinImpact,
                        scale: .skinImpact,
                        format: { "\(Int($0))" },
                        emptyText: String(localized: "Take the skin impact check monthly to see its trend here.")
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
    /// How a point's date reads; weekly series show the week, not a single day.
    var pointDate: (Date) -> String = { String(localized: "on \($0.formatted(date: .abbreviated, time: .omitted))") }
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
                Text("One entry so far: \(format(only.value)), \(pointDate(only.date)).")
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

#if DEBUG
#Preview("Empty") {
    InsightsView()
        .modelContainer(PreviewData.emptyContainer())
        .previewSetup()
}
#endif
