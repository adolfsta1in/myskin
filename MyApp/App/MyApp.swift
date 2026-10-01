import SwiftData
import SwiftUI
import UserNotifications

@main struct MyApp: App {
    @State private var settings: AppSettings
    @State private var lock: AppLock
    private let modelContainer: ModelContainer

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _lock = State(initialValue: AppLock(settings: settings))
        do {
            modelContainer = try AppModelContainer.makePersistent()
        } catch {
            // Never fall back to an empty store: the user would think their diary is gone.
            fatalError("Could not open the data store: \(error)")
        }
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        // Shared files (PDF, CSV) from the last session.
        ExportFolder.clear()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(lock)
        }
        .modelContainer(modelContainer)
    }
}
