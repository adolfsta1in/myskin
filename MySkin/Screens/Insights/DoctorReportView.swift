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
    @State private var isSharing = false

    enum ReportPeriod: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths
        var id: String { rawValue }
        var title: String {
            switch self {
            case .oneMonth: String(localized: "Last month")
            case .threeMonths: String(localized: "Last 3 months")
            case .sixMonths: String(localized: "Last 6 months")
            }
        }
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
            patient: DoctorReport.Patient(
                age: profiles.first?.birthYear.map { ProfileInfo.age(birthYear: $0) },
                sex: profiles.first?.sex,
                arthritis: profiles.first?.arthritisStatus
            ),
            checkIns: checkIns.map(\.reportSample),
            zones: assessments.datedScores,
            results: results.map(\.trendPoint),
            treatments: treatments.map(\.reportInput),
            // Photos aren't in device backups: after a restore, records can outlive their files.
            photos: photos
                .filter { PhotoStore.shared?.exists(fileName: $0.fileName) == true }
                .map { DoctorReport.PhotoInput(zoneID: $0.zoneID, day: $0.day, fileName: $0.fileName) }
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
                            ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                        }
                    } label: {
                        Label(period.title, systemImage: "calendar")
                            .font(.rounded(.headline, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)

                    Button {
                        isSharing = true
                    } label: {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
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
        .healthDataShare(isPresented: $isSharing) {
            [try ReportRenderer.makePDF(
                report: report,
                weeklyItch: Trends.weeklyItch(checkIns: checkIns.map(\.sample), from: report.start, to: report.end),
                images: images
            )]
        }
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
                label(String(localized: "Itch · weekly average"))
                ScoreTrendChart(data: weeklyItch, scale: .itch, height: 110)
            }

            label(String(localized: "Questionnaires"))
            VStack(alignment: .leading, spacing: 4) {
                line(report.skinImpactLatest.map { score in
                    let level = SkinImpact.level(for: score).title.inSentence
                    if let first = report.skinImpactFirst {
                        return String(localized: "Skin impact: \(first) → \(score) of \(SkinImpact.maxScore) · \(level)")
                    }
                    return String(localized: "Skin impact: \(score) of \(SkinImpact.maxScore) · \(level)")
                } ?? String(localized: "Skin impact: not taken in this period"))
                line(report.jointLatest.map { joint in
                    let maxScore = Questionnaires.maxScore(joint.kind)
                    return Questionnaires.needsAttention(joint.kind, score: joint.score)
                        ? String(localized: "\(joint.kind.title): \(joint.score) of \(maxScore) · joint symptoms noted")
                        : String(localized: "\(joint.kind.title): \(joint.score) of \(maxScore)")
                } ?? String(localized: "Joint check: not taken"))
                line(String(localized: "Patient-reported questionnaires written for MySkin; not validated clinical scores."))
                if let arthritis = ArthritisRules.reportText(report.patient.arthritis) {
                    line(arthritis)
                }
            }

            label(String(localized: "Treatment"))
            if report.treatments.isEmpty {
                line(String(localized: "No treatments logged in this period."))
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
                label(String(localized: "Logged triggers"))
                line(report.triggers.prefix(5).map { String(localized: "\($0.trigger.title) · \($0.days) days") }.joined(separator: ", "))
            }

            if !report.photos.isEmpty {
                label(String(localized: "Before / now"))
                HStack(alignment: .top, spacing: 8) {
                    ForEach(report.photos) { pair in
                        VStack(spacing: 4) {
                            HStack(spacing: 2) {
                                photo(pair.before)
                                photo(pair.now)
                            }
                            .frame(height: 56)
                            Text(BodyZone.named(id: pair.zoneID)?.name ?? "")
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

    /// «Age 34 · Female», or nil if neither was given.
    private var patientLine: String? {
        let parts = [report.patient.age.map { String(localized: "Age \($0)") }, report.patient.sex?.title].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MySkin · Skin summary")
                    .font(.rounded(.headline, weight: .bold))
                Text("\(report.start.formatted(.dateTime.month(.abbreviated).day())) – \(report.end.formatted(.dateTime.month(.abbreviated).day().year()))")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
                if let patient = patientLine {
                    Text(patient)
                        .font(.rounded(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
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
            stat(String(localized: "Body area (est.)"), change(report.severityBefore?.bsa, report.severityNow?.bsa) { String(localized: "\($0.formatted(.number.precision(.fractionLength(0...1))))%") })
            stat(String(localized: "Self-rated index"), change(report.severityBefore?.severityIndex, report.severityNow?.severityIndex) { $0.formatted(.number.precision(.fractionLength(1))) })
            stat(String(localized: "Avg itch"), change(report.itchBefore, report.itchNow) { $0.formatted(.number.precision(.fractionLength(1))) })
        }
    }

    @ViewBuilder
    private var severity: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let now = report.severityNow {
                line(now.isElevated
                     ? String(localized: "Self-estimated category: \(now.category.title) · raised by special sites or joint symptoms")
                     : String(localized: "Self-estimated category: \(now.category.title)"))
                if !now.specialSiteIDs.isEmpty {
                    let sites = now.specialSiteIDs.compactMap { BodyZone.named(id: $0)?.name }.formatted(.list(type: .and))
                    line(String(localized: "Special sites: \(sites)"))
                }
            } else {
                line(String(localized: "No body map assessments yet."))
            }
            line(String(localized: "Check-ins: \(report.checkInDays) days · with flare signs: \(report.flareDays)"))
        }
    }

    private func treatmentDetail(_ treatment: DoctorReport.TreatmentLine) -> String {
        var parts = [treatment.kind.title, treatment.schedule,
                     String(localized: "since \(treatment.startDate.formatted(date: .abbreviated, time: .omitted))")]
        if let end = treatment.endDate {
            let date = end.formatted(date: .abbreviated, time: .omitted)
            parts.append(treatment.stopReason.map { String(localized: "stopped \(date) (\($0))") } ?? String(localized: "stopped \(date)"))
        }
        if let adherence = treatment.adherence {
            parts.append(String(localized: "\(adherence.formatted(.percent.precision(.fractionLength(0)))) of planned doses marked done"))
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

#Preview {
    NavigationStack {
        DoctorReportView()
    }
    .previewSetup()
}
