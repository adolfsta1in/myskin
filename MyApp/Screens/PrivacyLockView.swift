import SwiftUI

/// Privacy lock screen. Face ID is simulated in the prototype.
struct PrivacyLockView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "faceid")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 140, height: 140)
                    .glassEffect(.regular.tint(Theme.accentSoft.opacity(0.5)), in: .circle)
                VStack(spacing: 10) {
                    Text("MySkin is locked")
                        .font(.rounded(.title, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Your photos are stored only on this device and protected by Face ID.")
                        .font(.rounded(.body))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                Spacer()
                VStack(spacing: 14) {
                    PrimaryButton(title: "Unlock with Face ID", systemImage: "faceid") {
                        withAnimation(.smooth) { store.isLocked = false }
                    }
                    Label("Nothing leaves your phone unless you share it", systemImage: "lock.fill")
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    PrivacyLockView()
        .previewSetup()
}
