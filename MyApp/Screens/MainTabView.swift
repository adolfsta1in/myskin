import SwiftUI

enum AppTab: Hashable {
    case today, body, photos, treatment, insights
}

struct MainTabView: View {
    @State private var selection: AppTab
    private let todayMode: AppMode

    init(selection: AppTab = .today, todayMode: AppMode = .calm) {
        _selection = State(initialValue: selection)
        self.todayMode = todayMode
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView(mode: todayMode)
            }
            Tab("Body", systemImage: "figure.stand", value: AppTab.body) {
                BodyMapView()
            }
            Tab("Photos", systemImage: "camera", value: AppTab.photos) {
                PhotosView()
            }
            Tab("Treatment", systemImage: "cross.vial", value: AppTab.treatment) {
                TreatmentView()
            }
            Tab("Insights", systemImage: "sparkles", value: AppTab.insights) {
                InsightsView()
            }
        }
        .tint(Theme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// Decides between onboarding, privacy lock and the main app.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingFlow()
                    .transition(.opacity)
            } else if store.isLocked {
                PrivacyLockView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: settings.hasCompletedOnboarding)
        .animation(.smooth, value: store.isLocked)
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
            // Re-lock when the app goes to the background.
            if phase == .background, settings.faceIDEnabled, settings.hasCompletedOnboarding {
                store.isLocked = true
            }
        }
    }
}

#Preview {
    MainTabView()
        .previewSetup()
}
