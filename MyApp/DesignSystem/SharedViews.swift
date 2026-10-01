import SwiftUI
import Charts

// MARK: - Body silhouette

/// Tappable body silhouette built from simple shapes. Zones fill with intensity color.
struct BodySilhouette: View {
    let side: BodySide
    let intensities: [String: Int]
    var onTap: (BodyZone) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / BodyZone.designSize.width
            let sy = geo.size.height / BodyZone.designSize.height
            ZStack(alignment: .topLeading) {
                ForEach(BodyZone.cached(for: side)) { zone in
                    let level = intensities[zone.id] ?? 0
                    zone.kind.shape
                        .fill(level == 0 ? Theme.sand : Theme.intensity(level: level))
                        .overlay(zone.kind.shape.stroke(.white.opacity(0.7), lineWidth: 1.5))
                        .frame(width: zone.rect.width * sx, height: zone.rect.height * sy)
                        .contentShape(zone.kind.shape)
                        .position(x: zone.rect.midX * sx, y: zone.rect.midY * sy)
                        .onTapGesture { onTap(zone) }
                        .accessibilityElement()
                        .accessibilityLabel(zone.name)
                        .accessibilityValue(IntensityLegend.label(for: level))
                        .accessibilityAddTraits(.isButton)
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
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { level in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.intensity(level: level))
                        .frame(width: 10, height: 10)
                    Text(Self.label(for: level))
                }
            }
        }
        .font(.rounded(.caption))
        .foregroundStyle(Theme.inkSoft)
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
    /// DLQI 0–30.
    case dlqi
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
        case .dlqi: [
            Band(range: 0...1, label: "No effect", color: Theme.intensityCalm),
            Band(range: 1...10, label: "Small–moderate", color: Theme.intensityMild),
            Band(range: 10...30, label: "Very large", color: Theme.intensityModerate),
        ]
        case .itch: [
            Band(range: 0...3, label: "Low", color: Theme.intensityCalm),
            Band(range: 3...7, label: "Medium", color: Theme.intensityMild),
            Band(range: 7...10, label: "High", color: Theme.intensityModerate),
        ]
        }
    }

    /// Y range: fixed for DLQI and itch, BSA grows with the data (at least 0–15 %).
    func domain(for data: [DayValue]) -> ClosedRange<Double> {
        switch self {
        case .bsa: 0...max(15, ((data.map(\.value).max() ?? 0) * 1.2).rounded(.up))
        case .dlqi: 0...30
        case .itch: 0...10
        }
    }

    func axisValues(for domain: ClosedRange<Double>) -> [Double] {
        switch self {
        case .bsa: [0, 3, 10, domain.upperBound]
        case .dlqi: [0, 10, 20, 30]
        case .itch: [0, 5, 10]
        }
    }

    /// Point color on the 0–10 intensity ramp.
    func intensity(_ value: Double) -> Double {
        switch self {
        case .bsa: min(value, 20) / 2
        case .dlqi: value / 3
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

// MARK: - Skin forecast

struct ForecastDay: Identifiable {
    let id = UUID()
    let label: String
    let humidity: Int
    let systemImage: String
}

/// Weather-style skin forecast card.
struct SkinForecastCard: View {
    var days: [ForecastDay] = [
        ForecastDay(label: "Today", humidity: 48, systemImage: "cloud.sun"),
        ForecastDay(label: "Tomorrow", humidity: 25, systemImage: "sun.max"),
        ForecastDay(label: "Sat", humidity: 31, systemImage: "wind"),
        ForecastDay(label: "Sun", humidity: 44, systemImage: "cloud"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Skin forecast", systemImage: "humidity")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("Your city")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("25%")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("humidity tomorrow")
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text("Tomorrow the air gets dry — apply a thicker cream tonight before bed.")
                .font(.rounded(.body))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        Text(day.label)
                            .font(.rounded(.caption, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                        Image(systemName: day.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.accent)
                        Text("\(day.humidity)%")
                            .font(.rounded(.footnote, weight: .semibold))
                            .foregroundStyle(day.humidity < 30 ? Theme.intensityModerate : Theme.ink)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 10)
            .background(.white.opacity(0.35), in: .rect(cornerRadius: 18))
        }
        .glassCard(tint: Theme.accentSoft)
    }
}

// MARK: - Fingertip unit illustration

/// Simple finger drawing with the fingertip-unit segment highlighted.
struct FingerIllustration: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Finger
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.sand)
                .frame(width: 44, height: 120)
            // Cream line from tip to first crease
            Capsule()
                .fill(.white)
                .overlay(Capsule().stroke(Theme.sandDeep, lineWidth: 1))
                .frame(width: 18, height: 42)
                .padding(.top, 8)
            // Creases
            VStack(spacing: 34) {
                Capsule().fill(Theme.sandDeep).frame(width: 26, height: 2)
                Capsule().fill(Theme.sandDeep).frame(width: 26, height: 2)
            }
            .padding(.top, 54)
        }
        .frame(width: 60, height: 124)
        .accessibilityLabel("A line of cream from the fingertip to the first crease")
    }
}
