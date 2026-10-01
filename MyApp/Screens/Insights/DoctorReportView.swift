import Charts
import SwiftData
import SwiftUI
import UIKit

struct DoctorReportView: View {
    @Query private var profiles: [Profile]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var assessments: [ZoneAssessment]
    @Query private var results: [QuestionnaireResult]
    @Query(sort: \Treatment.startDate) private var treatments: [Treatment]
    @Query private var photos: [Photo]
    @State private var period: ReportPeriod = .threeMonths
    /// Thumbnails for the before / now photos, loaded before they are drawn (also for the PDF).
    @State private var images: [String: UIImage] = [:]

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

    private var report: DoctorReport {
        DoctorReport.make(
            periodDays: period.days,
            endingOn: .now,
            psoriasisTypes: profiles.first?.psoriasisTypes ?? [],
            checkIns: checkIns.map(\.reportSample),
            zones: assessments.map(\.datedScore),
            results: results.map(\.trendPoint),
            treatments: treatments.map(\.reportInput),
            photos: photos.map { DoctorReport.PhotoInput(zoneID: $0.zoneID, day: $0.day, fileName: $0.fileName) }
        )
    }

    var body: some View {
        let report = report
        ScrollView {
            VStack(spacing: 18) {
                ReportPaper(
                    report: report,
                    weeklyItch: Trends.weeklyItch(checkIns: checkIns.map(\.sample), from: report.start, to: report.end),
                    images: images
                )
                .background(.white, in: .rect(cornerRadius: 14))
                .shadow(color: Theme.ink.opacity(0.12), radius: 20, y: 8)

                HStack(spacing: 12) {
                    Menu {
                        Picker("Period", selection: $period) {
                            ForEach(ReportPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label(period.rawValue, systemImage: "calendar")
                            .font(.rounded(.headline, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)

                    ShareLink(item: ReportText.make(report), subject: Text("MySkin report")) {
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
        .task(id: report.photos.flatMap { [$0.before, $0.now] }) {
            await loadImages(for: report.photos)
        }
    }

    private func loadImages(for pairs: [DoctorReport.PhotoPair]) async {
        guard let store = PhotoStore.shared else { return }
        var loaded: [String: UIImage] = [:]
        for name in pairs.flatMap({ [$0.before, $0.now] }) {
            if let image = images[name] {
                loaded[name] = image
            } else if let data = await store.thumbnailInBackground(fileName: name, maxPixelSize: 300), let image = UIImage(data: data) {
                loaded[name] = image
            }
        }
        images = loaded
    }
}

extension Treatment {
    var reportInput: DoctorReport.TreatmentInput {
        DoctorReport.TreatmentInput(
            id: "\(persistentModelID.hashValue)", name: name, kind: kind, schedule: doseSchedule,
            stopReason: stopReason, logs: doses.map(\.logged)
        )
    }
}

// MARK: - Paper

/// The one-page report. Plain views only (no Liquid Glass), so it renders to PDF as it looks here.
struct ReportPaper: View {
    let report: DoctorReport
    let weeklyItch: [DayValue]
    let images: [String: UIImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            stats
            severity

            if weeklyItch.count > 1 {
                label("Itch · weekly average")
                ScoreTrendChart(data: weeklyItch, scale: .itch, height: 110)
            }

            label("Questionnaires")
            VStack(alignment: .leading, spacing: 4) {
                line(report.dlqiLatest.map { score in
                    let change = report.dlqiFirst.map { "\($0) → " } ?? ""
                    return "DLQI: \(change)\(score) of 30 · \(DLQI.band(for: score).title.lowercased())"
                } ?? "DLQI: not taken in this period")
                line(report.pestLatest.map {
                    "PEST (joints): \($0) of 5\(PEST.suggestsRheumatologist($0) ? " · suggests a rheumatology referral" : "")"
                } ?? "PEST (joints): not taken")
            }

            label("Treatment")
            if report.treatments.isEmpty {
                line("No treatments logged in this period.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.treatments) { treatment in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(treatment.name).font(.rounded(.caption, weight: .semibold))
                            Text(treatmentDetail(treatment))
                                .font(.rounded(.caption2))
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !report.triggers.isEmpty {
                label("Logged triggers")
                line(report.triggers.prefix(5).map { "\($0.trigger.title) · \($0.days) \($0.days == 1 ? "day" : "days")" }.joined(separator: ", "))
            }

            if !report.photos.isEmpty {
                label("Before / now")
                HStack(alignment: .top, spacing: 8) {
                    ForEach(report.photos) { pair in
                        VStack(spacing: 4) {
                            HStack(spacing: 2) {
                                photo(pair.before)
                                photo(pair.now)
                            }
                            .frame(height: 56)
                            Text(BodyZone.zone(id: pair.zoneID)?.name ?? "")
                                .font(.rounded(.caption2))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Text("Self-reported diary data from the MySkin app. Severity index and area are the patient's own estimates, not a clinical PASI. Not a diagnosis.")
                .font(.rounded(.caption2))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MySkin · Skin summary")
                    .font(.rounded(.headline, weight: .bold))
                Text("\(report.start.formatted(.dateTime.month(.abbreviated).day())) – \(report.end.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Text(report.psoriasisTypes.isEmpty ? "Psoriasis" : "Psoriasis · \(report.psoriasisTypes.map(\.title).joined(separator: ", "))")
                .font(.rounded(.caption2, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.sageSoft, in: .capsule)
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat("Body area", change(report.severityBefore?.bsa, report.severityNow?.bsa) { "\($0.formatted(.number.precision(.fractionLength(0...1))))%" })
            stat("Severity index", change(report.severityBefore?.severityIndex, report.severityNow?.severityIndex) { $0.formatted(.number.precision(.fractionLength(1))) })
            stat("Avg itch", change(report.itchBefore, report.itchNow) { $0.formatted(.number.precision(.fractionLength(1))) })
        }
    }

    @ViewBuilder
    private var severity: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let now = report.severityNow {
                line("Category: \(now.category.title)\(now.isElevated ? " · elevated" : "")")
                if !now.specialSiteIDs.isEmpty {
                    line("Special sites: \(now.specialSiteIDs.compactMap { BodyZone.zone(id: $0)?.name }.formatted(.list(type: .and)))")
                }
            } else {
                line("No body map assessments yet.")
            }
            line("Check-ins: \(report.checkInDays) \(report.checkInDays == 1 ? "day" : "days") · with flare signs: \(report.flareDays)")
        }
    }

    private func treatmentDetail(_ treatment: DoctorReport.TreatmentLine) -> String {
        var parts = [treatment.kind.title, treatment.schedule, "since \(treatment.startDate.formatted(date: .abbreviated, time: .omitted))"]
        if let end = treatment.endDate {
            parts.append("stopped \(end.formatted(date: .abbreviated, time: .omitted))\(treatment.stopReason.map { " (\($0))" } ?? "")")
        }
        if let adherence = treatment.adherence {
            parts.append("\(adherence.formatted(.percent.precision(.fractionLength(0)))) of planned doses marked done")
        }
        return parts.joined(separator: " · ")
    }

    private func change(_ before: Double?, _ now: Double?, format: (Double) -> String) -> String {
        switch (before, now) {
        case let (before?, now?): "\(format(before)) → \(format(now))"
        case let (nil, now?): format(now)
        default: "—"
        }
    }

    private func photo(_ fileName: String) -> some View {
        Color.clear
            .overlay {
                if let image = images[fileName] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Theme.sand
                }
            }
            .clipShape(.rect(cornerRadius: 6))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.rounded(.caption2)).foregroundStyle(Theme.inkSoft)
            Text(value).font(.rounded(.subheadline, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Theme.cream, in: .rect(cornerRadius: 10))
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.rounded(.caption))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.rounded(.caption2, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 4)
    }
}

// MARK: - Text summary

enum ReportText {
    static func make(_ report: DoctorReport) -> String {
        var lines = ["MySkin report · \(report.start.formatted(date: .abbreviated, time: .omitted)) – \(report.end.formatted(date: .abbreviated, time: .omitted))"]
        if let now = report.severityNow {
            let before = report.severityBefore.map { "\($0.bsa.formatted(.number.precision(.fractionLength(0...1))))% → " } ?? ""
            lines.append("Body area: \(before)\(now.bsa.formatted(.number.precision(.fractionLength(0...1))))% · \(now.category.title)")
        }
        if let itch = report.itchNow {
            let before = report.itchBefore.map { "\($0.formatted(.number.precision(.fractionLength(1)))) → " } ?? ""
            lines.append("Average itch: \(before)\(itch.formatted(.number.precision(.fractionLength(1))))")
        }
        if let dlqi = report.dlqiLatest { lines.append("DLQI: \(dlqi) of 30") }
        if let pest = report.pestLatest { lines.append("PEST: \(pest) of 5") }
        if !report.treatments.isEmpty { lines.append("Treatments: \(report.treatments.map(\.name).joined(separator: ", "))") }
        lines.append("Self-reported diary data, not a diagnosis.")
        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        DoctorReportView()
    }
    .previewSetup()
}
