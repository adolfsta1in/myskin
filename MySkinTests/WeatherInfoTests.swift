import Foundation
import Testing
@testable import MySkin

struct WeatherInfoTests {
    @Test func convertsWeatherKitValues() {
        let reading = WeatherInfo.reading(temperatureCelsius: 18.4, humidityFraction: 0.31, uvNow: 2, uvMaxToday: 6)
        #expect(reading.temperature == 18.4)
        #expect(abs(reading.humidity - 31) < 0.0001)
        #expect(reading.uvIndex == 2)
        #expect(reading.uvIndexMax == 6)
    }

    @Test func missingDailyUVFallsBackToUVNow() {
        let reading = WeatherInfo.reading(temperatureCelsius: 5, humidityFraction: 0.8, uvNow: 3, uvMaxToday: nil)
        #expect(reading.uvIndexMax == 3)
        // Today's peak is never below the UV now.
        #expect(WeatherInfo.reading(temperatureCelsius: 5, humidityFraction: 0.8, uvNow: 4, uvMaxToday: 2).uvIndexMax == 4)
    }

    @Test func humidityIsClampedToPercent() {
        #expect(WeatherInfo.reading(temperatureCelsius: 0, humidityFraction: 1.2, uvNow: 0, uvMaxToday: 0).humidity == 100)
        #expect(WeatherInfo.reading(temperatureCelsius: 0, humidityFraction: -0.1, uvNow: -1, uvMaxToday: nil).humidity == 0)
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

    @Test func coordinatesAreRoundedBeforeTheyLeaveTheDevice() {
        #expect(WeatherInfo.rounded(43.238949) == 43.24)
        #expect(WeatherInfo.rounded(76.889709) == 76.89)
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
