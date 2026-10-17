import SwiftData
import SwiftUI

struct BodyMapView: View {
    @Query private var assessments: [ZoneAssessment]
    @Query(sort: \QuestionnaireResult.date, order: .reverse) private var questionnaires: [QuestionnaireResult]
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    #if DEBUG
    @State private var side: BodySide = ScreenshotMode.bodySide
    #else
    @State private var side: BodySide = .front
    #endif
    @State private var lastTapped: BodyZone?
    @State private var editingZone: BodyZone?
    @State private var tapCount = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var bsaFontSize = 40.0

    /// The latest joint check feeds the «elevated» mark.
    private var summary: BodyMapSummary {
        let joints = Questionnaires.jointSymptomsNoted(results: questionnaires.map(\.trendPoint))
        return BodyMapSummary.make(
            zones: assessments.datedScores,
            arthritisSuspected: ArthritisRules.isSuspected(status: profiles.first?.arthritisStatus, jointSymptomsNoted: joints)
        )
    }

    var body: some View {
        let summary = summary
        let levels = summary.levels
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Body map")
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Tap an area to rate it.")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                    Picker("Side", selection: $side) {
                        ForEach(BodySide.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    VStack(spacing: 12) {
                        BodySilhouette(side: side, intensities: levels) { zone in
                            lastTapped = zone
                            editingZone = zone
                            tapCount += 1
                        }
                        // Scale with the screen: compact on iPhone SE/11, larger on Pro Max.
                        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.46, 300), 440) }
                        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
                        .id(side)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))

                        Text(lastTappedDescription(levels))
                            .font(.rounded(.footnote, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .contentTransition(.opacity)
                        IntensityLegend()
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .animation(.smooth, value: side)

                    quickZones(levels)
                    summaryCard(summary)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenScaffold()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingZone) { zone in
                ZoneAssessmentSheet(zone: zone, current: ZoneAssessmentDraft.latest(zoneID: zone.id, in: assessments)?.score)
            }
        }
    }

    private func lastTappedDescription(_ levels: [String: Int]) -> String {
        guard let lastTapped else { return String(localized: "Front and back views are tracked separately") }
        return String(localized: "\(lastTapped.name) · \(IntensityLegend.label(for: levels[lastTapped.id] ?? 0))")
    }

    private func quickZones(_ levels: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: String(localized: "Quick zones"), subtitle: String(localized: "Hard-to-draw areas"))
            GlassEffectContainer(spacing: 10) {
            // Two columns don't fit the longest names at the largest text sizes.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                ForEach(BodyZone.quickZones) { zone in
                    let level = levels[zone.id] ?? 0
                    Button {
                        editingZone = zone
                    } label: {
                        HStack {
                            Circle()
                                .fill(Theme.intensity(level: level))
                                .frame(width: 14, height: 14)
                                .accessibilityHidden(true)
                            Text(zone.name)
                                .font(.rounded(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Text(IntensityLegend.label(for: level))
                                .font(.rounded(.caption))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the rating for this area")
                    .sensoryFeedback(.selection, trigger: level)
                }
            }
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private func summaryCard(_ summary: BodyMapSummary) -> some View {
        let snapshot = summary.snapshot
        VStack(alignment: .leading, spacing: 14) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your estimated area")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                    Text("≈ \(snapshot.bsa, format: .number.precision(.fractionLength(0...1)))%")
                        .font(.system(size: bsaFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("of body surface")
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
                .accessibilityElement(children: .combine)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 6) {
                    Text(snapshot.category.title)
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.intensity(level: snapshot.category.rawValue + 1).opacity(0.6), in: .capsule)
                    Text("Self-rated index \(snapshot.severityIndex, format: .number.precision(.fractionLength(1)))")
                        .font(.rounded(.caption))
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            if let change = summary.bsaChange {
                let amount = abs(change).formatted(.number.precision(.fractionLength(1)))
                Label(
                    change == 0 ? String(localized: "Same area as the previous assessment")
                        : change < 0 ? String(localized: "\(amount)% less vs previous assessment")
                        : String(localized: "\(amount)% more vs previous assessment"),
                    systemImage: change < 0 ? "arrow.down.right" : change > 0 ? "arrow.up.right" : "equal"
                )
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(change <= 0 ? Theme.sageDeep : Theme.intensityModerate)
            } else if summary.lastAssessed == nil {
                Text("Tap an area on the map to start. The total updates as you go.")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }

            if snapshot.isElevated {
                elevatedNote(snapshot)
            }

            if let day = summary.lastAssessed {
                Text("Your own estimate, not a clinical measurement · updated \(day.formatted(.dateTime.month().day()))")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard(tint: (summary.bsaChange ?? 0) < 0 ? Theme.sageSoft : nil)
        .animation(.smooth, value: snapshot.bsa)
    }

    /// Special site or suspected arthritis (spec §2.2): a hint to talk to the doctor, not a diagnosis.
    private func elevatedNote(_ snapshot: SeveritySnapshot) -> some View {
        let names = snapshot.specialSiteIDs.compactMap { BodyZone.zone(id: $0)?.name }
        let joints = profiles.first?.arthritisStatus == .diagnosed ? String(localized: "Psoriatic arthritis") : String(localized: "Your joint answers")
        let reason = names.isEmpty ? joints : String(localized: "Special area: \(names.formatted(.list(type: .and)))")
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Theme.intensitySevere)
            VStack(alignment: .leading, spacing: 2) {
                Text("Worth discussing · \(reason)")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Show this to your doctor at your next visit.")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    BodyMapView()
        .previewSetup()
}

#Preview("Largest text") {
    BodyMapView()
        .previewSetup()
        .dynamicTypeSize(.accessibility5)
}
