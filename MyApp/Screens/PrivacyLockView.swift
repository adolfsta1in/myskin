import SwiftUI

/// Shown on launch and after returning from the background while the lock is on.
/// Asks for Face ID / Touch ID once on appear, with the device passcode as fallback.
struct PrivacyLockView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasPrompted = false
    @State private var isAuthenticating = false

    private let method = BiometricAuth.method

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: method.systemImage)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 140, height: 140)
                    .glassEffect(.regular.tint(Theme.accentSoft.opacity(0.5)), in: .circle)
                VStack(spacing: 10) {
                    Text("MySkin is locked")
                        .font(.rounded(.title, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Unlock to open your diary.")
                        .font(.rounded(.body))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                Spacer()
                PrimaryButton(title: "Unlock with \(method.title)", systemImage: method.systemImage) {
                    Task { await unlock() }
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        // Prompt once when the app is active; the prompt itself makes the app inactive and
        // active again, so prompting on every phase change would loop after a cancel.
        .task(id: scenePhase) {
            guard scenePhase == .active, !hasPrompted else { return }
            hasPrompted = true
            await unlock()
        }
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        await lock.unlock()
        isAuthenticating = false
    }
}

#Preview {
    PrivacyLockView()
        .previewSetup()
}
