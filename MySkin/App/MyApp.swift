import SwiftData
import SwiftUI
import UserNotifications

@main struct MyApp: App {
    @State private var settings: AppSettings
    @State private var lock: AppLock
    @State private var weather = WeatherModel()
    @State private var remoteConfig = RemoteConfigStore()
    @State private var subscriptions = Subscriptions()
    /// nil if the store couldn't be opened. Never fall back to an empty store: the user would
    /// think their diary is gone. `StoreRecoveryView` offers retry, a copy, or a new diary.
    @State private var modelContainer: ModelContainer?

    init() {
        #if DEBUG
        // `-onboardingDemo`: onboarding → paywall on throwaway settings and an
        // in-memory store, so a phone with a real diary can try it without touching the diary.
        if ProcessInfo.processInfo.arguments.contains("-onboardingDemo"),
           let defaults = UserDefaults(suiteName: "MySkin.onboardingDemo") {
            defaults.removePersistentDomain(forName: "MySkin.onboardingDemo")
            let demo = AppSettings(defaults: defaults)
            _settings = State(initialValue: demo)
            _lock = State(initialValue: AppLock(settings: demo))
            _modelContainer = State(initialValue: try? AppModelContainer.makeInMemory())
            UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
            return
        }
        #endif
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
                    .environment(subscriptions)
                    .task { subscriptions.start() }
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
