import SwiftData
import SwiftUI

extension Patterns {
    /// The report takes a moment on a year of diary, so it runs off the main actor.
    @concurrent
    static func reportInBackground(days: [PatternDay], calendar: Calendar = .current) async -> PatternReport {
        report(days: days, calendar: calendar)
    }
}

/// «Patterns» on Insights: up to three findings from the user's own diary, or how long until the first look.
struct PatternsCard: View {
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]
    @Query private var treatments: [Treatment]
    @Query private var doseLogs: [DoseLog]
    @State private var report: PatternReport?

    /// Everything the report reads, so an edit that keeps the counts (a re-rated zone,
    /// a changed schedule) still recomputes it.
    private struct Inputs: Hashable {
        let checkIns: [PatternDay]
        let zones: [DatedZoneScore]
        let treatments: [PatternTreatment]
    }

    private var inputs: Inputs {
        // `doseLogs` is queried only so that a new mark refreshes the card; treatments carry their logs.
        _ = doseLogs.count
        return Inputs(
            checkIns: checkIns.map(\.patternDay),
            zones: assessments.datedScores,
            treatments: treatments.map { PatternTreatment(schedule: $0.doseSchedule, logs: $0.doses.map(\.logged)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: String(localized: "Patterns"), subtitle: String(localized: "What went with your itch, from your own diary"), systemImage: "sparkle.magnifyingglass")
            content
        }
        .glassCard()
        .task(id: inputs) {
            let inputs = inputs
            let days = PatternInput.days(
                checkIns: inputs.checkIns,
                zones: inputs.zones,
                treatments: inputs.treatments,
                asOf: .now
            )
            report = await Patterns.reportInBackground(days: days)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let report {
            if report.checkInsUntilFirstAnalysis > 0 {
                waiting(report)
            } else if report.findings.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    VelviMascot(mood: .thinking, size: 56)
                    Text("No clear links yet. Keep logging triggers and food — patterns need a few repeats to show.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                seeAll(report, title: String(localized: "What was checked"))
            } else {
                ForEach(report.findings.prefix(3)) { finding in
                    PatternRow(finding: finding)
                }
                seeAll(report, title: report.findings.count > 3 ? String(localized: "See all \(report.findings.count)") : String(localized: "Details"))
            }
        } else {
            HStack(spacing: 8) {
                ProgressView()
                Text("Looking for patterns…")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func waiting(_ report: PatternReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VelviMascot(mood: .thinking, size: 56)
                Text("Keep logging — \(report.checkInsUntilFirstAnalysis) more check-ins to look for patterns.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProgressView(value: Double(report.checkInDays), total: Double(Patterns.Threshold.minCheckIns))
                .tint(Theme.accent)
            Text("Log triggers and food on most days: links between them and your itch show up after about three weeks.")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func seeAll(_ report: PatternReport, title: String) -> some View {
        NavigationLink {
            PatternDetailView(report: report)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.rounded(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }
}

/// One finding in a line: direction, what, how sure.
private struct PatternRow: View {
    let finding: PatternFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PatternDirectionIcon(direction: finding.direction)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.summary)
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(PatternText.badge(finding))
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PatternDirectionIcon: View {
    let direction: PatternDirection

    var body: some View {
        Image(systemName: direction == .worse ? "arrow.up.right" : "arrow.down.right")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(direction == .worse ? Theme.intensitySevere : Theme.sageDeep)
            .frame(width: 32, height: 32)
            .background((direction == .worse ? Theme.intensityMild : Theme.sageSoft).opacity(0.6), in: .circle)
            .accessibilityLabel(direction == .worse ? String(localized: "Higher itch") : String(localized: "Lower itch"))
    }
}

private enum PatternText {
    /// «Moderate link · 9 times · early sign»
    static func badge(_ finding: PatternFinding) -> String {
        let strength = switch finding.strength {
        case .weak: String(localized: "Weak link")
        case .moderate: String(localized: "Moderate link")
        case .strong: String(localized: "Strong link")
        }
        var parts = [strength, String(localized: "\(finding.episodes) times")]
        if finding.isEarly { parts.append(String(localized: "early sign")) }
        return parts.joined(separator: " · ")
    }

    static func percent(_ share: Double) -> String {
        share.formatted(.percent.precision(.fractionLength(0)))
    }
}

/// All findings with their numbers, plus what was checked without a clear link and what needs more data.
struct PatternDetailView: View {
    let report: PatternReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Based on \(report.checkInDays) check-ins.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)

                ForEach(report.findings) { finding in
                    findingCard(finding)
                }

                if !report.unclear.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: String(localized: "No clear link yet"), subtitle: String(localized: "Checked, and itch looked about the same with or without"))
                        Text(report.unclear.map(\.title).formatted(.list(type: .and)))
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.ink)
                    }
                    .glassCard()
                }

                if !report.notEnoughData.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: String(localized: "Not enough data yet"), subtitle: String(localized: "Needs at least \(Patterns.Threshold.minEpisodes) separate times, with days without it in between"))
                        ForEach(report.notEnoughData) { pending in
                            HStack {
                                Text(pending.title)
                                Spacer()
                                Text("\(pending.episodes) times")
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.ink)
                        }
                    }
                    .glassCard()
                }

                Text("Patterns from your own diary, not proof of cause. Discuss with your doctor before changing your diet or treatment.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenScaffold()
        .navigationTitle("Patterns")
        .navigationBarTitleDisplayMode(.large)
    }

    private func findingCard(_ finding: PatternFinding) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PatternDirectionIcon(direction: finding.direction)
                VStack(alignment: .leading, spacing: 2) {
                    Text(finding.summary)
                        .font(.rounded(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(PatternText.badge(finding))
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            HStack(spacing: 10) {
                number(String(localized: "\(Patterns.number(finding.meanItchExposed))"), caption: String(localized: "itch after \(Patterns.subject(finding.factor, title: finding.title))"))
                number(String(localized: "\(Patterns.number(finding.meanItchUnexposed))"), caption: String(localized: "itch on other days"))
            }
            Text("Days with flare signs: \(PatternText.percent(finding.flareShareExposed)) vs \(PatternText.percent(finding.flareShareUnexposed)).")
                .font(.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
            Text(finding.explanation)
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.ink)
            if finding.isEarly {
                Label("Early sign — fewer than six weeks of check-ins. Keep logging to see if it holds.", systemImage: "hourglass")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard()
    }

    private func number(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.rounded(.title2, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(caption)
                .font(.rounded(.caption))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cream.opacity(0.6), in: .rect(cornerRadius: 16))
    }
}

#if DEBUG
#Preview("Patterns") {
    NavigationStack {
        ScrollView { PatternsCard().padding() }
            .screenScaffold()
    }
    .modelContainer(PreviewData.container)
    .previewSetup()
}
#endif
