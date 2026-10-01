import SwiftData
import SwiftUI
import UserNotifications

@main struct MyApp: App {
    @State private var store = AppStore()
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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(lock)
        }
        .modelContainer(modelContainer)
    }
}
