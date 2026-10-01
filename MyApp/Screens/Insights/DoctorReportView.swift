import SwiftUI
import Charts

struct DoctorReportView: View {
    @Environment(AppStore.self) private var store
    @State private var period: ReportPeriod = .threeMonths

    enum ReportPeriod: String, CaseIterable, Identifiable {
        case oneMonth = "Last month"
        case threeMonths = "Last 3 months"
        case sixMonths = "Last 6 months"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .oneMonth: 30
            case .threeMonths: 91
            case .sixMonths: 182
            }
        }
    }

    private var periodStart: Date {
        Calendar.current.date(byAdding: .day, value: -period.days, to: .now) ?? .now
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                paper
                HStack(spacing: 12) {
                    Menu {
                        Picker("Period", selection: $period) {
                            ForEach(ReportPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Choose period", systemImage: "calendar")
                            .font(.rounded(.headline, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)

                    ShareLink(item: summaryText, subject: Text("MySkin report")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.rounded(.headline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenScaffold()
        .navigationTitle("Doctor report")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Paper preview

    private var paper: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MySkin · Skin summary")
                        .font(.rounded(.headline, weight: .bold))
                    Text("\(periodStart.formatted(.dateTime.month(.abbreviated).day())) – \(Date.now.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.rounded(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Text(store.condition?.title ?? "Atopic dermatitis")
                    .font(.rounded(.caption2, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.sageSoft, in: .capsule)
            }

            HStack(spacing: 8) {
                stat("\(store.scoreName)", "16 → 8")
                stat("Avg itch", "5.8 → 3.0")
                stat("Area", "6% → \(Int(store.affectedArea.rounded()))%")
            }

            reportLabel("Weekly score")
            ScoreTrendChart(data: store.weeklyScores, scale: .dlqi, height: 110)

            reportLabel("Before / now")
            HStack(spacing: 8) {
                ForEach(store.photoZones.prefix(3)) { zone in
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            AbstractSkinPlaceholder(seed: zone.photos.first?.seed ?? 0, calmness: zone.photos.first?.calmness ?? 0.2, cornerRadius: 6)
                            AbstractSkinPlaceholder(seed: zone.photos.last?.seed ?? 1, calmness: zone.photos.last?.calmness ?? 0.8, cornerRadius: 6)
                        }
                        .frame(height: 44)
                        Text(zone.name).font(.rounded(.caption2)).foregroundStyle(Theme.inkSoft)
                    }
                }
            }

            reportLabel("Treatment timeline")
            Chart(store.treatments) { treatment in
                BarMark(
                    xStart: .value("Start", max(treatment.started, periodStart)),
                    xEnd: .value("End", Date.now),
                    y: .value("Treatment", treatment.name)
                )
                .foregroundStyle(Theme.accent.opacity(0.6))
                .cornerRadius(4)
            }
            .chartXScale(domain: periodStart...Date.now)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { _ in AxisValueLabel().font(.system(size: 8)) }
            }
            .frame(height: 100)

            reportLabel("Noticed triggers")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(store.insights.filter { $0.confidence >= 0.4 }) { insight in
                    Text("• \(insight.text) (\(insight.evidence.lowercased()))")
                        .font(.rounded(.caption))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .background(.white, in: .rect(cornerRadius: 14))
        .shadow(color: Theme.ink.opacity(0.12), radius: 20, y: 8)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.rounded(.caption2)).foregroundStyle(Theme.inkSoft)
            Text(value).font(.rounded(.subheadline, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Theme.cream, in: .rect(cornerRadius: 10))
    }

    private func reportLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.rounded(.caption2, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 4)
    }

    private var summaryText: String {
        """
        MySkin report · \(period.rawValue)
        \(store.scoreName): 16 → 8
        Average itch: 5.8 → 3.0
        Estimated area: 6% → \(Int(store.affectedArea.rounded()))%
        Treatments: \(store.treatments.map(\.name).joined(separator: ", "))
        Noticed triggers:
        \(store.insights.filter { $0.confidence >= 0.4 }.map { "• \($0.text)" }.joined(separator: "\n"))
        """
    }
}

#Preview {
    NavigationStack {
        DoctorReportView()
    }
    .previewSetup()
}
