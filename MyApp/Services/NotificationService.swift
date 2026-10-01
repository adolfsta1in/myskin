import UserNotifications

/// Keeps pending local notifications equal to `ReminderPlan`. Only touches the app's own ids.
enum NotificationService {
    /// Replaces our pending reminders. Does nothing until the user has allowed notifications,
    /// so the system dialog is never shown from here.
    static func sync(_ reminders: [PlannedReminder]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlan.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.dateComponents, repeats: reminder.repeats)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}

/// Shows reminders as banners even while MySkin is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
