import CoreLocation
import Foundation
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
    private let provider: any WeatherProvider

    /// Readings younger than this are reused.
    static let freshFor: TimeInterval = 30 * 60

    init(provider: any WeatherProvider = OpenMeteoWeather()) {
        self.provider = provider
        state = LocationProvider.status == .notDetermined ? .needsPermission
            : LocationProvider.isDenied ? .denied : .loading
    }

    var reading: WeatherReading? {
        if case .loaded(let reading) = state { reading } else { nil }
    }

    /// Loads the weather if location is allowed. With `askPermission` the system prompt may appear.
    func refresh(askPermission: Bool = false) async {
        if let updatedAt, reading != nil, Date.now.timeIntervalSince(updatedAt) < Self.freshFor { return }
        if LocationProvider.isDenied { state = .denied; return }
        if LocationProvider.status == .notDetermined && !askPermission { state = .needsPermission; return }
        state = .loading
        do {
            let location = try await withTimeout(seconds: 20) {
                try await LocationProvider.currentLocation(askPermission: askPermission)
            }
            let reading = try await provider.reading(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            state = .loaded(reading)
            updatedAt = .now
        } catch LocationProvider.LocationError.denied {
            state = LocationProvider.status == .notDetermined ? .needsPermission : .denied
        } catch {
            state = .failed
        }
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
