import CoreLocation
import Foundation
import MapKit
import Observation
import UIKit

/// Source of weather data. Open-Meteo for now; WeatherKit can replace it without touching screens.
protocol WeatherProvider: Sendable {
    func reading(latitude: Double, longitude: Double) async throws -> WeatherReading
}

/// Open-Meteo forecast API: no key, CC BY 4.0 (attribution is shown on the card).
nonisolated struct OpenMeteoWeather: WeatherProvider {
    func reading(latitude: Double, longitude: Double) async throws -> WeatherReading {
        guard let url = WeatherInfo.openMeteoURL(latitude: latitude, longitude: longitude) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try WeatherInfo.parseOpenMeteo(data)
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
    }

    private(set) var state: State
    private(set) var updatedAt: Date?
    /// City (or area) name for the card, from Apple's reverse geocoder; nil if unknown.
    private(set) var placeName: String?
    private let provider: any WeatherProvider
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored private var failedAt: Date?

    /// Daily request count (no location). Never rename: existing installs read these.
    enum Key {
        static let requestDay = "weatherRequestDay"
        static let requestCount = "weatherRequestCount"
    }

    init(provider: any WeatherProvider = OpenMeteoWeather(), defaults: UserDefaults = .standard) {
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
        guard !isFetching, WeatherRequestPolicy.mayRequest(
            now: .now,
            lastSuccess: reading == nil ? nil : updatedAt,
            lastFailure: failedAt,
            isManual: isManual || askPermission,
            daily: dailyCount
        ) else {
            // Nothing new to show and no request allowed: don't spin forever.
            if state == .loading { state = .failed }
            return
        }
        isFetching = true
        defer { isFetching = false }
        state = .loading
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
        } catch LocationProvider.LocationError.denied {
            state = LocationProvider.status == .notDetermined ? .needsPermission : .denied
        } catch {
            state = .failed
            failedAt = .now
        }
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
