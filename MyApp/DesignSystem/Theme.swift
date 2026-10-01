import SwiftUI

/// Central palette, spacing and typography for MySkin.
/// Warm neutrals + one calm accent. Intensity colors are reserved for charts and the body map.
enum Theme {
    // MARK: Brand neutrals
    static let cream = Color(hex: 0xF6F1E7)
    static let creamDeep = Color(hex: 0xEFE7D8)
    static let sand = Color(hex: 0xE8DCC6)
    static let sandDeep = Color(hex: 0xD6C4A5)
    static let sage = Color(hex: 0xA9BFA3)
    static let sageSoft = Color(hex: 0xDCE6D5)
    static let sageDeep = Color(hex: 0x5E7560)

    // MARK: Text
    static let ink = Color(hex: 0x3B3A33)
    static let inkSoft = Color(hex: 0x7C786B)

    // MARK: Accent (dusty teal-blue)
    static let accent = Color(hex: 0x5B8A9A)
    static let accentSoft = Color(hex: 0xD4E4E7)

    // MARK: Intensity ramp — charts and body map only
    static let intensityCalm = Color(hex: 0xB9CDB2)
    static let intensityMild = Color(hex: 0xE6CB93)
    static let intensityModerate = Color(hex: 0xDDA36C)
    static let intensitySevere = Color(hex: 0xC27A5E)

    /// Discrete intensity for body zones (0 = none, 1 mild, 2 moderate, 3 severe).
    static func intensity(level: Int) -> Color {
        switch level {
        case ...0: sand
        case 1: intensityMild
        case 2: intensityModerate
        default: intensitySevere
        }
    }

    /// Continuous intensity for a 0–10 value (itch, scores normalised to 10).
    static func intensity(value: Double) -> Color {
        switch value {
        case ..<2.5: intensityCalm
        case ..<5: intensityMild
        case ..<7.5: intensityModerate
        default: intensitySevere
        }
    }

    // MARK: Layout
    static let cardRadius: CGFloat = 28
    static let screenPadding: CGFloat = 20
}

extension Color {
    /// Creates a color from a 24-bit hex value, e.g. `0xF6F1E7`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension View {
    /// Light, rounded styling plus a sample store — used by previews.
    func previewSetup(_ store: AppStore = .preview) -> some View {
        environment(store)
            .fontDesign(.rounded)
            .preferredColorScheme(.light)
    }
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

/// Warm cream background with soft color fields so Liquid Glass has something to refract.
/// A single static mesh gradient — much cheaper than stacked blurred shapes.
struct WarmBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.45], [0.6, 0.5], [1, 0.4],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Theme.sageSoft, Theme.cream, Theme.cream,
                Theme.cream, Theme.cream, Theme.accentSoft,
                Theme.sand, Theme.creamDeep, Theme.creamDeep,
            ]
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
