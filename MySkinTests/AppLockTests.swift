import Foundation
import Testing
@testable import MyApp

struct AppLockTests {
    private func settings(faceID: Bool, onboarded: Bool) -> AppSettings {
        let suite = "AppLockTests-\(UUID().uuidString)"
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite) ?? .standard)
        settings.faceIDEnabled = faceID
        settings.hasCompletedOnboarding = onboarded
        return settings
    }

    @Test func launchesLockedOnlyWhenLockIsOn() {
        #expect(AppLock(settings: settings(faceID: true, onboarded: true)).isLocked)
        #expect(!AppLock(settings: settings(faceID: false, onboarded: true)).isLocked)
        #expect(!AppLock(settings: settings(faceID: true, onboarded: false)).isLocked)
    }
}
