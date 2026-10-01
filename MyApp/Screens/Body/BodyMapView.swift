import SwiftData
import SwiftUI

struct BodyMapView: View {
    @Environment(AppStore.self) private var store
    @Query private var assessments: [ZoneAssessment]
    @State private var side: BodySide = .front
    @State private var lastTapped: BodyZone?
    @State private var editingZone: BodyZone?
    @State private var tapCount = 0

    var body: some View {
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
                        BodySilhouette(side: side, intensities: store.zoneIntensity) { zone in
                            lastTapped = zone
                            editingZone = zone
                            tapCount += 1
                        }
                        // Scale with the screen: compact on iPhone SE/11, larger on Pro Max.
                        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.46, 300), 440) }
                        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
                        .id(side)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))

                        Text(lastTappedDescription)
                            .font(.rounded(.footnote, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .contentTransition(.opacity)
                        IntensityLegend()
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .animation(.smooth, value: side)

                    quickZones
                    areaCard
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

    private var lastTappedDescription: String {
        guard let lastTapped else { return "Front and back views are tracked separately" }
        return "\(lastTapped.name) · \(IntensityLegend.label(for: store.zoneIntensity[lastTapped.id] ?? 0))"
    }

    private var quickZones: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick zones", subtitle: "Hard-to-draw areas")
            GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(BodyZone.quickZones) { zone in
                    let level = store.zoneIntensity[zone.id] ?? 0
                    Button {
                        editingZone = zone
                    } label: {
                        HStack {
                            Circle()
                                .fill(Theme.intensity(level: level))
                                .frame(width: 14, height: 14)
                            Text(zone.name)
                                .font(.rounded(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(IntensityLegend.label(for: level))
                                .font(.rounded(.caption))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: level)
                }
            }
            }
        }
        .glassCard()
    }

    private var areaCard: some View {
        let change = store.affectedArea - store.lastWeekArea
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated area")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                Text("≈ \(store.affectedArea, format: .number.precision(.fractionLength(0...1)))%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("of body surface")
                    .font(.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Label(
                    "\(abs(change), format: .number.precision(.fractionLength(1)))% \(change <= 0 ? "less" : "more")",
                    systemImage: change <= 0 ? "arrow.down.right" : "arrow.up.right"
                )
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(change <= 0 ? Theme.sageDeep : Theme.intensityModerate)
                Text("than last week (\(store.lastWeekArea, format: .number.precision(.fractionLength(1)))%)")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard(tint: change <= 0 ? Theme.sageSoft : nil)
        .animation(.smooth, value: store.affectedArea)
    }
}

#Preview {
    BodyMapView()
        .previewSetup()
}
