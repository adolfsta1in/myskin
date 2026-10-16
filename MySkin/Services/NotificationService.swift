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

    /// Outside `ReminderPlan.idPrefix` on purpose: `sync` must not remove it.
    static let trialReminderID = "trial.ending"
    static let trialReminderBody = "Your free trial ends in \(PaywallOffer.reminderDaysBeforeEnd) days."

    /// One-off reminder promised on the paywall timeline. Silently skipped without permission.
    static func scheduleTrialReminder(at date: Date) async {
        guard await NotificationPermission.isAllowed(), date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = ReminderPlan.title
        content.body = trialReminderBody
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: trialReminderID, content: content, trigger: trigger)
        )
    }

    /// Removes all of MySkin's pending and delivered reminders (used by «Delete all data»).
    static func removeAll() async {
        let center = UNUserNotificationCenter.current()
        let isOurs: (String) -> Bool = { $0.hasPrefix(ReminderPlan.idPrefix) || $0 == trialReminderID }
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter(isOurs)
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter(isOurs)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
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
