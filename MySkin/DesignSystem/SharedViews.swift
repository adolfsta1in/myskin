import SwiftUI
import Charts

// MARK: - Body silhouette

/// Tappable body illustration. Affected zones are tinted with their intensity color, clipped to the body outline.
struct BodySilhouette: View {
    let side: BodySide
    let intensities: [String: Int]
    var onTap: (BodyZone) -> Void = { _ in }

    private var artwork: Image {
        Image(side == .front ? "BodyFront" : "BodyBack")
    }

    /// Lines between neighbouring zones in `BodyZone.designSize` space; they follow the zone rects
    /// and are clipped to the body outline, so they can run past it.
    private static let borders: [(CGPoint, CGPoint)] = {
        var lines: [(CGPoint, CGPoint)] = [
            // No lines on the neck: it's a quick zone, too small to tap here.
            (CGPoint(x: 61, y: 150), CGPoint(x: 139, y: 150)),  // chest | abdomen
            (CGPoint(x: 50, y: 212), CGPoint(x: 150, y: 212)),  // abdomen | hips
            (CGPoint(x: 48, y: 250), CGPoint(x: 152, y: 250)),  // hips | thighs
            (CGPoint(x: 48, y: 320), CGPoint(x: 152, y: 320)),  // thighs | knees
            (CGPoint(x: 48, y: 348), CGPoint(x: 152, y: 348)),  // knees | shins
            (CGPoint(x: 48, y: 428), CGPoint(x: 152, y: 428)),  // shins | feet
        ]
        let arm: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 61, y: 74), CGPoint(x: 61, y: 146)),    // upper arm | chest
            (CGPoint(x: 15, y: 154), CGPoint(x: 60, y: 154)),   // upper arm | elbow
            (CGPoint(x: 12, y: 180), CGPoint(x: 61, y: 180)),   // elbow | forearm
            (CGPoint(x: 0, y: 228), CGPoint(x: 46, y: 228)),    // forearm | hand
        ]
        let width = BodyZone.designSize.width
        for (start, end) in arm {
            lines.append((start, end))
            lines.append((CGPoint(x: width - start.x, y: start.y), CGPoint(x: width - end.x, y: end.y)))
        }
        return lines
    }()

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / BodyZone.designSize.width
            let sy = geo.size.height / BodyZone.designSize.height
            let zones = BodyZone.cached(for: side)
            ZStack(alignment: .topLeading) {
                artwork
                    .resizable()
                    .accessibilityHidden(true)

                // Tints: soft-edged zone shapes, masked by the illustration so they follow the body.
                ZStack(alignment: .topLeading) {
                    ForEach(zones) { zone in
                        let level = intensities[zone.id] ?? 0
                        zone.kind.shape
                            .fill(Theme.intensity(level: level))
                            .opacity(level == 0 ? 0 : 0.8)
                            .frame(width: zone.rect.width * sx, height: zone.rect.height * sy)
                            .position(x: zone.rect.midX * sx, y: zone.rect.midY * sy)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .blur(radius: 2.5)
                .mask { artwork.resizable() }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                // Zone borders: dashed cuts across the body show where each tappable area ends.
                Path { path in
                    for (start, end) in Self.borders {
                        path.move(to: CGPoint(x: start.x * sx, y: start.y * sy))
                        path.addLine(to: CGPoint(x: end.x * sx, y: end.y * sy))
                    }
                }
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .mask { artwork.resizable() }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                ForEach(zones) { zone in
                    let level = intensities[zone.id] ?? 0
                    Color.clear
                        .frame(width: zone.rect.width * sx, height: zone.rect.height * sy)
                        .contentShape(zone.kind.shape)
                        .position(x: zone.rect.midX * sx, y: zone.rect.midY * sy)
                        .onTapGesture { onTap(zone) }
                        .accessibilityElement()
                        .accessibilityLabel(zone.name)
                        .accessibilityValue(IntensityLegend.label(for: level))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Opens the rating for this area")
                        // VoiceOver activates the zone directly, not by a synthesized tap at its centre.
                        .accessibilityAction { onTap(zone) }
                }
            }
        }
        .aspectRatio(BodyZone.designSize.width / BodyZone.designSize.height, contentMode: .fit)
        .animation(.smooth(duration: 0.25), value: intensities)
    }
}

/// Severity scale for the body map: 0 clear … 3 severe (`SeverityCalculator.level`).
struct IntensityLegend: View {
    static func label(for level: Int) -> String {
        switch level {
        case 1: "Mild"
        case 2: "Moderate"
        case 3: "Severe"
        default: "Clear"
        }
    }

    var body: some View {
        // Four labels don't fit in a row at the largest text sizes: then two by two.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { items }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow { item(0); item(1) }
                GridRow { item(2); item(3) }
            }
        }
        .font(.rounded(.caption))
        .foregroundStyle(Theme.inkSoft)
        .accessibilityElement(children: .combine)
    }

    private var items: some View {
        ForEach(0..<4, id: \.self) { item($0) }
    }

    private func item(_ level: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Theme.intensity(level: level))
                .frame(width: 10, height: 10)
            Text(Self.label(for: level))
                .fixedSize()
        }
    }
}

// MARK: - Charts

struct ItchMiniChart: View {
    let data: [DayValue]
    var height: CGFloat = 110

    var body: some View {
        Chart(data) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Itch", day.value),
                width: .ratio(0.55)
            )
            .foregroundStyle(Theme.intensity(value: day.value).gradient)
            .cornerRadius(5)
        }
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(values: [0, 5, 10]) { _ in
                AxisGridLine().foregroundStyle(Theme.sandDeep.opacity(0.4))
                AxisValueLabel().foregroundStyle(Theme.inkSoft)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(height: height)
        .accessibilityLabel("Itch over the last 14 days")
    }
}

/// What a trend chart shows: its range and soft bands.
enum ScoreScale {
    /// Affected body surface, %.
    case bsa
    /// Skin impact questionnaire 0–18.
    case skinImpact
    /// Itch 0–10.
    case itch

    struct Band {
        let range: ClosedRange<Double>
        let label: String
        let color: Color
    }

    var bands: [Band] {
        switch self {
        case .bsa: [
            Band(range: 0...3, label: "Mild", color: Theme.intensityCalm),
            Band(range: 3...10, label: "Moderate", color: Theme.intensityMild),
            Band(range: 10...100, label: "Severe", color: Theme.intensityModerate),
        ]
        case .skinImpact: [
            Band(range: 0...4, label: "Small", color: Theme.intensityCalm),
            Band(range: 4...10, label: "Moderate", color: Theme.intensityMild),
            Band(range: 10...18, label: "Large", color: Theme.intensityModerate),
        ]
        case .itch: [
            Band(range: 0...3, label: "Low", color: Theme.intensityCalm),
            Band(range: 3...7, label: "Medium", color: Theme.intensityMild),
            Band(range: 7...10, label: "High", color: Theme.intensityModerate),
        ]
        }
    }

    /// Y range: fixed for skin impact and itch, BSA grows with the data (at least 0–15 %).
    func domain(for data: [DayValue]) -> ClosedRange<Double> {
        switch self {
        case .bsa: 0...max(15, ((data.map(\.value).max() ?? 0) * 1.2).rounded(.up))
        case .skinImpact: 0...Double(SkinImpact.maxScore)
        case .itch: 0...10
        }
    }

    func axisValues(for domain: ClosedRange<Double>) -> [Double] {
        switch self {
        case .bsa: [0, 3, 10, domain.upperBound]
        case .skinImpact: [0, 6, 12, 18]
        case .itch: [0, 5, 10]
        }
    }

    /// Point color on the 0–10 intensity ramp.
    func intensity(_ value: Double) -> Double {
        switch self {
        case .bsa: min(value, 20) / 2
        case .skinImpact: value / 1.8
        case .itch: value
        }
    }
}

/// Line chart over time with soft severity bands (Insights, doctor report).
struct ScoreTrendChart: View {
    let data: [DayValue]
    let scale: ScoreScale
    var height: CGFloat = 180

    var body: some View {
        let domain = scale.domain(for: data)
        Chart {
            ForEach(scale.bands, id: \.label) { band in
                RectangleMark(
                    yStart: .value("From", min(band.range.lowerBound, domain.upperBound)),
                    yEnd: .value("To", min(band.range.upperBound, domain.upperBound))
                )
                .foregroundStyle(band.color.opacity(0.18))
            }
            ForEach(data) { point in
                LineMark(x: .value("Date", point.date), y: .value("Score", point.value))
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", point.date), y: .value("Score", point.value))
                    .foregroundStyle(Theme.intensity(value: scale.intensity(point.value)))
                    .symbolSize(40)
            }
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(values: scale.axisValues(for: domain)) { _ in
                AxisGridLine().foregroundStyle(Theme.sandDeep.opacity(0.4))
                AxisValueLabel().foregroundStyle(Theme.inkSoft)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Fingertip unit illustration

/// Index finger with a line of cream from the tip to the first crease (one fingertip unit).
struct FingerIllustration: View {
    var body: some View {
        Image("FingertipUnit")
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 124)
            .accessibilityLabel("A line of cream from the fingertip to the first crease")
    }
}
