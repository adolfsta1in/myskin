import SwiftUI

/// Shown instead of the app when the remote config says this version must not be used
/// (a critical bug). The diary isn't touched; it opens again after the update.
struct UpdateRequiredView: View {
    /// App Store page from the config; without it the user is pointed to the App Store app.
    let updateURL: URL?

    @Environment(\.openURL) private var openURL
    /// Safety information stays reachable even when the app itself isn't.
    @State private var showsSafety = false

    var body: some View {
        ZStack {
            WarmBackground()
            ScrollView {
                VStack(spacing: 24) {
                    VelviMascot(mood: .caring, size: 140, isIdle: false)
                        .padding(.top, 40)
                    VStack(spacing: 10) {
                        Text("Please update Velvi")
                            .font(.rounded(.title2, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("This version has a problem that's fixed in a newer one. Your diary is safe and will be here after the update.")
                            .font(.rounded(.body))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    if let updateURL {
                        PrimaryButton(title: "Open the App Store", systemImage: "arrow.up.right") {
                            openURL(updateURL)
                        }
                    } else {
                        Text("Open the App Store and update Velvi.")
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                    }
                    Button("Urgent symptoms?") { showsSafety = true }
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $showsSafety) {
            RedFlagView(flags: RedFlag.allCases)
        }
    }
}

#if DEBUG
#Preview {
    UpdateRequiredView(updateURL: URL(string: "https://apps.apple.com/app/id0"))
}
#endif
