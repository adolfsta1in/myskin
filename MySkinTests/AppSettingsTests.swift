import Foundation
import Testing
@testable import MyApp

struct AppSettingsTests {
    /// Isolated defaults domain, wiped before use.
    private func makeDefaults() -> UserDefaults? {
        let suite = "MySkinTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)
        defaults?.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func freshInstallDefaults() throws {
        let settings = AppSettings(defaults: try #require(makeDefaults()))
        #expect(!settings.hasCompletedOnboarding)
        #expect(!settings.faceIDEnabled)
        #expect(settings.checkInReminder)
        #expect(settings.doseReminders)
        #expect(settings.checkInMinutes == 20 * 60)
    }

    @Test func valuesSurviveRelaunch() throws {
        let defaults = try #require(makeDefaults())
        let first = AppSettings(defaults: defaults)
        first.hasCompletedOnboarding = true
        first.faceIDEnabled = true
        first.checkInReminder = false
        first.doseReminders = false
        first.checkInMinutes = 21 * 60 + 30

        // A new instance over the same defaults behaves like the next app launch.
        let relaunched = AppSettings(defaults: defaults)
        #expect(relaunched.hasCompletedOnboarding)
        #expect(relaunched.faceIDEnabled)
        #expect(!relaunched.checkInReminder)
        #expect(!relaunched.doseReminders)
        #expect(relaunched.checkInMinutes == 21 * 60 + 30)
    }

    @Test func checkInTimeMapsToMinutes() throws {
        let settings = AppSettings(defaults: try #require(makeDefaults()))
        let time = try #require(Calendar.current.date(bySettingHour: 7, minute: 45, second: 0, of: .now))
        settings.checkInTime = time
        #expect(settings.checkInMinutes == 7 * 60 + 45)
        #expect(Calendar.current.dateComponents([.hour, .minute], from: settings.checkInTime) == DateComponents(hour: 7, minute: 45))
    }
}
