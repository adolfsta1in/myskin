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

    // MARK: Open-Meteo

    static func openMeteoURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(rounded(latitude))),
            URLQueryItem(name: "longitude", value: String(rounded(longitude))),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,uv_index"),
            URLQueryItem(name: "daily", value: "uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        return components?.url
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let relative_humidity_2m: Double
            let uv_index: Double?
        }
        struct Daily: Decodable {
            let uv_index_max: [Double?]
        }
        let current: Current
        let daily: Daily?
    }

    static func parseOpenMeteo(_ data: Data) throws -> WeatherReading {
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let uvNow = response.current.uv_index ?? 0
        let uvMax = response.daily?.uv_index_max.first.flatMap(\.self) ?? uvNow
        return WeatherReading(
            temperature: response.current.temperature_2m,
            humidity: response.current.relative_humidity_2m,
            uvIndex: uvNow,
            uvIndexMax: max(uvMax, uvNow)
        )
    }
}
