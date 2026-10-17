import CoreLocation
import Foundation
import MapKit
import Observation
import OSLog
import UIKit
import WeatherKit

/// Source of weather data, behind a protocol so screens don't depend on it.
protocol WeatherProvider: Sendable {
    func reading(latitude: Double, longitude: Double) async throws -> WeatherReading
    /// Credit the card has to show next to the data; nil if it couldn't be loaded.
    func credit() async -> WeatherCredit?
}

/// Required attribution of the weather source: its mark and the legal page.
nonisolated struct WeatherCredit: Equatable, Sendable {
    let serviceName: String
    /// Mark for a light background — the app always uses the light appearance.
    let markURL: URL
    let legalPageURL: URL

    /// Shown if WeatherKit's attribution couldn't be loaded.
    static let appleWeatherLegalPage = URL(string: "https://weatherkit.apple.com/legal-attribution.html")
}

/// Apple WeatherKit (needs the WeatherKit capability and App Service on the App ID).
/// Like the geocoder, it only gets coordinates rounded to about 1 km.
nonisolated struct AppleWeather: WeatherProvider {
    func reading(latitude: Double, longitude: Double) async throws -> WeatherReading {
        let location = CLLocation(latitude: WeatherInfo.rounded(latitude), longitude: WeatherInfo.rounded(longitude))
        let (current, daily) = try await WeatherService.shared.weather(for: location, including: .current, .daily)
        return WeatherInfo.reading(
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            humidityFraction: current.humidity,
            uvNow: current.uvIndex.value,
            uvMaxToday: daily.first?.uvIndex.value
        )
    }

    func credit() async -> WeatherCredit? {
        guard let attribution = try? await WeatherService.shared.attribution else { return nil }
        return WeatherCredit(
            serviceName: attribution.serviceName,
            markURL: attribution.combinedMarkLightURL,
            legalPageURL: attribution.legalPageURL
        )
    }
}

/// Approximate device location for the weather. Nothing is stored.
enum LocationProvider {
    enum LocationError: Error {
        case denied
        case unavailable
    }

    static var status: CLAuthorizationStatus { CLLocationManager().authorizationStatus }

    static var isDenied: Bool {
        status == .denied || status == .restricted
    }

    /// First location fix. `askPermission` shows the system prompt if the user hasn't answered yet.
    static func currentLocation(askPermission: Bool) async throws -> CLLocation {
        let session = askPermission ? CLServiceSession(authorization: .whenInUse) : nil
        defer { session?.invalidate() }
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location { return location }
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw LocationError.denied
            }
            // Without permission and without asking, there's nothing to wait for.
            if !askPermission && status == .notDetermined { throw LocationError.denied }
        }
        throw LocationError.unavailable
    }
}

/// Today's weather for the card and the check-in. Lives for the app session.
@Observable
final class WeatherModel {
    enum State: Equatable {
        /// Location permission hasn't been asked yet.
        case needsPermission
        case denied
        case loading
        case loaded(WeatherReading)
        case failed
        /// Today's `WeatherRequestPolicy.maxPerDay` requests are used up; «Try again» can't help until tomorrow.
        case limitReached
    }

    private(set) var state: State
    private static let log = Logger(subsystem: "app.myskin.ios", category: "weather")
    private(set) var updatedAt: Date?
    /// City (or area) name for the card, from Apple's reverse geocoder; nil if unknown.
    private(set) var placeName: String?
    /// Attribution of the weather source, loaded once with the first reading.
    private(set) var credit: WeatherCredit?
    private let provider: any WeatherProvider
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored private var failedAt: Date?

    /// Daily request count (no location). Never rename: existing installs read these.
    enum Key {
        static let requestDay = "weatherRequestDay"
        static let requestCount = "weatherRequestCount"
    }

    init(provider: any WeatherProvider = AppleWeather(), defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        state = LocationProvider.status == .notDetermined ? .needsPermission
            : LocationProvider.isDenied ? .denied : .loading
    }

    var reading: WeatherReading? {
        if case .loaded(let reading) = state { reading } else { nil }
    }

    /// Loads the weather if location is allowed and `WeatherRequestPolicy` lets a request go out.
    /// With `askPermission` the system prompt may appear; `isManual` is the «Try again» button.
    func refresh(askPermission: Bool = false, isManual: Bool = false) async {
        if LocationProvider.isDenied { state = .denied; return }
        if LocationProvider.status == .notDetermined && !askPermission { state = .needsPermission; return }
        #if DEBUG
        // Test runs launch the app as their host: no WeatherKit calls from there.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        // Runs from Xcode would use up the daily cap within an hour of work; Release keeps it.
        let daily: WeatherRequestPolicy.DailyCount? = nil
        #else
        let daily = dailyCount
        #endif
        guard !isFetching, WeatherRequestPolicy.mayRequest(
            now: .now,
            lastSuccess: reading == nil ? nil : updatedAt,
            lastFailure: failedAt,
            isManual: isManual || askPermission,
            daily: daily
        ) else {
            // Nothing new to show and no request allowed: don't spin forever.
            let today = daily?.current(on: .now) ?? 0
            if today >= WeatherRequestPolicy.maxPerDay {
                Self.log.notice("Weather request not sent: daily limit of \(WeatherRequestPolicy.maxPerDay, privacy: .public) reached")
                if reading == nil { state = .limitReached }
            } else if state == .loading {
                state = .failed
            }
            return
        }
        isFetching = true
        defer { isFetching = false }
        // Today's reading stays on the card (and goes into the check-in) while a newer one loads.
        let kept = keptReading
        if kept == nil { state = .loading }
        do {
            let location = try await withTimeout(seconds: 20) {
                try await LocationProvider.currentLocation(askPermission: askPermission)
            }
            dailyCount = (dailyCount ?? WeatherRequestPolicy.DailyCount(day: .now, count: 0)).adding(on: .now)
            let reading = try await provider.reading(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            state = .loaded(reading)
            updatedAt = .now
            failedAt = nil
            placeName = await Self.placeName(for: location)
            if credit == nil { credit = await provider.credit() }
        } catch LocationProvider.LocationError.denied {
            state = LocationProvider.status == .notDetermined ? .needsPermission : .denied
        } catch {
            // Domain and code only: the description can carry the request URL with coordinates.
            let nsError = error as NSError
            Self.log.error("Weather failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            state = kept.map { .loaded($0) } ?? .failed
            failedAt = .now
        }
    }

    /// The current reading if it was fetched today; an older one isn't today's weather.
    private var keptReading: WeatherReading? {
        guard let reading, let updatedAt, Calendar.current.isDateInToday(updatedAt) else { return nil }
        return reading
    }

    private var dailyCount: WeatherRequestPolicy.DailyCount? {
        get {
            guard let day = defaults.object(forKey: Key.requestDay) as? Date else { return nil }
            return WeatherRequestPolicy.DailyCount(day: day, count: defaults.integer(forKey: Key.requestCount))
        }
        set {
            defaults.set(newValue?.day, forKey: Key.requestDay)
            defaults.set(newValue?.count, forKey: Key.requestCount)
        }
    }

    /// Name isn't required: on any failure the card just shows no place.
    /// Like the weather request, the geocoder only gets coordinates rounded to about 1 km.
    private static func placeName(for location: CLLocation) async -> String? {
        let coarse = CLLocation(
            latitude: WeatherInfo.rounded(location.coordinate.latitude),
            longitude: WeatherInfo.rounded(location.coordinate.longitude)
        )
        guard let request = MKReverseGeocodingRequest(location: coarse),
              let item = try? await request.mapItems.first else { return nil }
        return item.addressRepresentations?.cityName ?? item.name
    }

    private func withTimeout<T: Sendable>(seconds: Double, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw LocationProvider.LocationError.unavailable
            }
            guard let result = try await group.next() else { throw LocationProvider.LocationError.unavailable }
            group.cancelAll()
            return result
        }
    }
}
