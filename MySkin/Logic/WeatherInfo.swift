import Foundation

/// Weather at the user's approximate location, from `WeatherProvider`.
nonisolated struct WeatherReading: Equatable, Sendable {
    /// Air temperature now, °C.
    let temperature: Double
    /// Relative humidity now, %.
    let humidity: Double
    /// UV index now.
    let uvIndex: Double
    /// Highest UV index today; this is what is stored with the check-in.
    let uvIndexMax: Double
}

/// WHO UV index bands.
nonisolated enum UVLevel: Equatable, Sendable {
    case low, moderate, high, veryHigh, extreme

    init(index: Double) {
        switch index {
        case ..<3: self = .low
        case ..<6: self = .moderate
        case ..<8: self = .high
        case ..<11: self = .veryHigh
        default: self = .extreme
        }
    }

    var title: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        case .veryHigh: "Very high"
        case .extreme: "Extreme"
        }
    }
}

/// Short, neutral notes for the weather card. Not advice — sun exposure is a doctor's call.
nonisolated enum WeatherInfo {
    /// Humidity below this reads as dry air.
    static let dryHumidity = 35.0
    /// Humidity above this reads as humid air.
    static let humidHumidity = 70.0

    static func humidityTitle(_ humidity: Double) -> String {
        if humidity < dryHumidity { return "Dry" }
        if humidity > humidHumidity { return "Humid" }
        return "Comfortable"
    }

    static func notes(for reading: WeatherReading) -> [String] {
        var notes: [String] = []
        if reading.humidity < dryHumidity {
            notes.append("Dry air can make skin feel tighter and itchier.")
        }
        switch UVLevel(index: reading.uvIndexMax) {
        case .low:
            break
        case .moderate:
            notes.append("Some people find a little sun helps their psoriasis, but sunburn can trigger a flare. Ask your doctor how much sun is right for you.")
        case .high, .veryHigh, .extreme:
            notes.append("Strong sun today — sunburn can trigger a flare. Ask your doctor how much sun is right for you.")
        }
        return notes
    }

    /// Coordinates are rounded to about 1 km before they leave the device.
    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    // MARK: WeatherKit

    /// WeatherKit gives humidity as 0…1 and UV as whole numbers; the card and the check-in use % and Double.
    /// `uvMaxToday` is nil when the daily forecast is missing — then today's peak is at least the UV now.
    static func reading(temperatureCelsius: Double, humidityFraction: Double, uvNow: Int, uvMaxToday: Int?) -> WeatherReading {
        let uvNow = Double(max(uvNow, 0))
        return WeatherReading(
            temperature: temperatureCelsius,
            humidity: min(max(humidityFraction, 0), 1) * 100,
            uvIndex: uvNow,
            uvIndexMax: max(Double(uvMaxToday ?? 0), uvNow)
        )
    }
}
