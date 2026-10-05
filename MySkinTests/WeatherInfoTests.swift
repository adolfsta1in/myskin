import Foundation
import Testing
@testable import MySkin

struct WeatherInfoTests {
    @Test func parsesOpenMeteo() throws {
        let json = """
        {"current":{"time":"2026-10-03T14:00","temperature_2m":18.4,"relative_humidity_2m":31,"uv_index":2.1},
         "daily":{"time":["2026-10-03"],"uv_index_max":[5.6]}}
        """
        let reading = try WeatherInfo.parseOpenMeteo(Data(json.utf8))
        #expect(reading == WeatherReading(temperature: 18.4, humidity: 31, uvIndex: 2.1, uvIndexMax: 5.6))
    }

    @Test func missingUVFallsBackToZero() throws {
        let json = #"{"current":{"temperature_2m":5,"relative_humidity_2m":80,"uv_index":null}}"#
        let reading = try WeatherInfo.parseOpenMeteo(Data(json.utf8))
        #expect(reading.uvIndexMax == 0)
    }

    @Test func uvBands() {
        #expect(UVLevel(index: 2.9) == .low)
        #expect(UVLevel(index: 3) == .moderate)
        #expect(UVLevel(index: 7.5) == .high)
        #expect(UVLevel(index: 10) == .veryHigh)
        #expect(UVLevel(index: 11) == .extreme)
    }

    @Test func notesForDryAirAndSun() {
        let calm = WeatherReading(temperature: 20, humidity: 50, uvIndex: 1, uvIndexMax: 2)
        #expect(WeatherInfo.notes(for: calm).isEmpty)
        let dryAndSunny = WeatherReading(temperature: 20, humidity: 20, uvIndex: 6, uvIndexMax: 8)
        #expect(WeatherInfo.notes(for: dryAndSunny).count == 2)
        #expect(WeatherInfo.humidityTitle(20) == "Dry")
        #expect(WeatherInfo.humidityTitle(85) == "Humid")
    }

    @Test func coordinatesAreRoundedInTheRequest() throws {
        let url = try #require(WeatherInfo.openMeteoURL(latitude: 43.238949, longitude: 76.889709))
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.first { $0.name == "latitude" }?.value == "43.24")
        #expect(query.first { $0.name == "longitude" }?.value == "76.89")
    }

    @Test func weatherIsSavedWithTheCheckIn() {
        var draft = CheckInDraft()
        draft.weather = WeatherReading(temperature: 12, humidity: 40, uvIndex: 1, uvIndexMax: 4)
        let checkIn = draft.makeCheckIn(day: .now)
        #expect(checkIn.humidity == 40)
        #expect(checkIn.uvIndex == 4)
        #expect(checkIn.temperature == 12)

        // Updating without a reading keeps the saved weather.
        var update = CheckInDraft(checkIn)
        update.itch = 5
        update.apply(to: checkIn)
        #expect(checkIn.humidity == 40)
    }
}
