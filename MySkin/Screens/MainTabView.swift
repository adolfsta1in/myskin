import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case today, body, photos, treatment, insights
}

struct MainTabView: View {
    @State private var selection: AppTab

    init(selection: AppTab = .today) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                TodayView()
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
        .modifier(ReminderSync())
    }
}

/// Re-plans local reminders whenever treatments, dose marks or reminder settings change,
/// and each time the app comes to the foreground (so the 7-day dose window keeps moving).
private struct ReminderSync: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Treatment> { $0.endDate == nil }) private var treatments: [Treatment]
    @Query private var doseLogs: [DoseLog]

    /// Changes whenever the planned reminders could change.
    private var signature: String {
        let schedules = treatments.map { "\($0.doseSchedule.hashValue)" }.sorted().joined(separator: ",")
        return [
            "\(settings.hasCompletedOnboarding)", "\(settings.checkInReminder)", "\(settings.checkInMinutes)", "\(settings.doseReminders)",
            schedules, "\(doseLogs.count)", "\(scenePhase == .active)",
        ].joined(separator: "|")
    }

    func body(content: Content) -> some View {
        content.task(id: signature) {
            // After «Delete all data» the tabs are on their way out; don't plan reminders again.
            guard scenePhase == .active, settings.hasCompletedOnboarding else { return }
            let reminders = ReminderPlan.reminders(
                now: .now,
                checkInEnabled: settings.checkInReminder,
                checkInMinutes: settings.checkInMinutes,
                dosesEnabled: settings.doseReminders,
                schedules: treatments.map(\.reminderSchedule)
            )
            await NotificationService.sync(reminders)
        }
    }
}

/// Decides between onboarding, privacy lock and the main app.
/// Content is covered whenever the app is not active (app switcher, Control Center).
struct RootView: View {
    @Environment(AppLock.self) private var lock
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingFlow()
                    .transition(.opacity)
            } else if lock.isLocked {
                PrivacyLockView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if scenePhase != .active && settings.hasCompletedOnboarding {
                PrivacyCover()
            }
        }
        .animation(.smooth, value: settings.hasCompletedOnboarding)
        .animation(.smooth, value: lock.isLocked)
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, phase in
            // Re-lock when the app goes to the background.
            if phase == .background, settings.faceIDEnabled, settings.hasCompletedOnboarding {
                lock.isLocked = true
            }
        }
        .onChange(of: settings.faceIDEnabled) { _, enabled in
            if !enabled { lock.isLocked = false }
        }
    }
}

/// Hides the diary in the app switcher snapshot.
private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            WarmBackground()
                .opacity(0.85)
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    MainTabView()
        .previewSetup()
}
