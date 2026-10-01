import UserNotifications

/// System permission for local reminders. Reminder texts stay neutral (no diagnosis, no drug names).
enum NotificationPermission {
    /// Shows the system dialog the first time; later calls return the stored answer.
    static func request() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
}
