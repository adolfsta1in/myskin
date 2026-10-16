import SwiftUI

/// Shown instead of the app when the diary store can't be opened. Nothing is deleted here:
/// the user can retry, keep a copy of the store file, or set the store aside and start over.
struct StoreRecoveryView: View {
    /// Tries to open the store again; true on success (the app then replaces this screen).
    let retry: () -> Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var isSharing = false
    @State private var isConfirmingNewDiary = false
    @State private var stillFailing = false
    @State private var error: String?

    var body: some View {
        ZStack {
            WarmBackground()
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 130, height: 130)
                        .glassEffect(.regular.tint(Theme.accentSoft.opacity(0.5)), in: .circle)
                        .padding(.top, 40)
                    VStack(spacing: 10) {
                        Text("MySkin can't open your diary")
                            .font(.rounded(.title2, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("Your entries haven't been deleted. Try again — restarting your iPhone often helps. If it keeps happening, save a copy of the diary file and send it to us so we can help.")
                            .font(.rounded(.body))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                        if stillFailing {
                            Text("Still can't open it.")
                                .font(.rounded(.footnote, weight: .semibold))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    VStack(spacing: 12) {
                        PrimaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                            stillFailing = !retry()
                        }
                        SecondaryButton(title: "Save a copy of the diary file") { isSharing = true }
                        if let contact = AppLinks.contactSupport {
                            Link("Contact support", destination: contact)
                                .font(.rounded(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.accent)
                                .padding(.top, 8)
                        }
                        Button("Start a new diary", role: .destructive) { isConfirmingNewDiary = true }
                            .font(.rounded(.subheadline, weight: .medium))
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        // The store can be unreadable while the iPhone is still locked; retry once it's in use.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { _ = retry() }
        }
        .healthDataShare(isPresented: $isSharing) {
            try AppModelContainer.copyStoreFiles()
        }
        .confirmationDialog("Start a new diary?", isPresented: $isConfirmingNewDiary, titleVisibility: .visible) {
            Button("Start a new diary", role: .destructive) { startNewDiary() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("MySkin will open with an empty diary. The current diary file is set aside on this iPhone, not deleted, so it may still be recovered. Photos stay. «Delete all data» in Settings removes it.")
        }
        .alert("Couldn't start a new diary", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func startNewDiary() {
        do {
            try AppModelContainer.setStoreAside()
            stillFailing = !retry()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    StoreRecoveryView { false }
}
