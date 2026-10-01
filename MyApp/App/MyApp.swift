import SwiftData
import SwiftUI

@main struct MyApp: App {
    @State private var store = AppStore()
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try AppModelContainer.makePersistent()
        } catch {
            // Never fall back to an empty store: the user would think their diary is gone.
            fatalError("Could not open the data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(modelContainer)
    }
}
