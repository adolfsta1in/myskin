import Foundation
import Observation

/// Flags and preferences that survive relaunch, backed by `UserDefaults`.
/// Health data lives in SwiftData, not here.
@Observable
final class AppSettings {
    /// Stored keys. Never rename: existing installs read these.
    enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let faceIDEnabled = "faceIDEnabled"
        static let checkInReminder = "checkInReminder"
        static let checkInMinutes = "checkInMinutes"
        static let doseReminders = "doseReminders"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    /// Off by default: the lock is only switched on by an explicit choice.
    var faceIDEnabled: Bool {
        didSet { defaults.set(faceIDEnabled, forKey: Key.faceIDEnabled) }
    }

    var checkInReminder: Bool {
        didSet { defaults.set(checkInReminder, forKey: Key.checkInReminder) }
    }

    /// Daily check-in reminder time as minutes after midnight (20:00 by default).
    var checkInMinutes: Int {
        didSet { defaults.set(checkInMinutes, forKey: Key.checkInMinutes) }
    }

    var doseReminders: Bool {
        didSet { defaults.set(doseReminders, forKey: Key.doseReminders) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.hasCompletedOnboarding: false,
            Key.faceIDEnabled: false,
            Key.checkInReminder: true,
            Key.checkInMinutes: 20 * 60,
            Key.doseReminders: true,
        ])
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        faceIDEnabled = defaults.bool(forKey: Key.faceIDEnabled)
        checkInReminder = defaults.bool(forKey: Key.checkInReminder)
        checkInMinutes = defaults.integer(forKey: Key.checkInMinutes)
        doseReminders = defaults.bool(forKey: Key.doseReminders)
    }

    /// Back to a fresh install: onboarding again, lock off, default reminders.
    func resetAll() {
        for key in [Key.hasCompletedOnboarding, Key.faceIDEnabled, Key.checkInReminder, Key.checkInMinutes, Key.doseReminders] {
            defaults.removeObject(forKey: key)
        }
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        faceIDEnabled = defaults.bool(forKey: Key.faceIDEnabled)
        checkInReminder = defaults.bool(forKey: Key.checkInReminder)
        checkInMinutes = defaults.integer(forKey: Key.checkInMinutes)
        doseReminders = defaults.bool(forKey: Key.doseReminders)
    }

    /// Today's date at `checkInMinutes` — for `DatePicker` and display.
    var checkInTime: Date {
        get {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: .now)
            return calendar.date(byAdding: .minute, value: checkInMinutes, to: start) ?? start
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            checkInMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}
