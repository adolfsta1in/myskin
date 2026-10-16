import SwiftData
import SwiftUI
import UserNotifications

@main struct MyApp: App {
    @State private var settings: AppSettings
    @State private var lock: AppLock
    @State private var weather = WeatherModel()
    @State private var remoteConfig = RemoteConfigStore()
    /// nil if the store couldn't be opened. Never fall back to an empty store: the user would
    /// think their diary is gone. `StoreRecoveryView` offers retry, a copy, or a new diary.
    @State private var modelContainer: ModelContainer?

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _lock = State(initialValue: AppLock(settings: settings))
        _modelContainer = State(initialValue: Self.openStore())
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        // Shared files (PDF, CSV) from the last session.
        ExportFolder.clear()
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootView()
                    .environment(settings)
                    .environment(lock)
                    .environment(weather)
                    .environment(remoteConfig)
                    .modelContainer(modelContainer)
            } else {
                StoreRecoveryView {
                    modelContainer = Self.openStore()
                    return modelContainer != nil
                }
            }
        }
    }

    private static func openStore() -> ModelContainer? {
        do {
            return try AppModelContainer.makePersistent()
        } catch {
            print("Could not open the data store: \(error)")
            return nil
        }
    }
}
