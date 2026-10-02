import SwiftUI
import UIKit

extension View {
    /// Warns that the files contain health data, then builds them and opens the system share sheet.
    /// Old exports are removed before the next export and on launch (not on close: AirDrop may still be sending).
    func healthDataShare(isPresented: Binding<Bool>, makeFiles: @escaping () throws -> [URL]) -> some View {
        modifier(HealthDataShare(isAsking: isPresented, makeFiles: makeFiles))
    }
}

private struct HealthDataShare: ViewModifier {
    @Binding var isAsking: Bool
    let makeFiles: () throws -> [URL]
    @State private var error: String?

    func body(content: Content) -> some View {
        content
            .alert("This contains health data", isPresented: $isAsking) {
                Button("Continue") {
                    do {
                        let files = try makeFiles()
                        // Let the alert finish closing before presenting over the screen.
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            ShareSheet.present(files)
                        }
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only share it with people you trust, such as your doctor. Once it leaves MySkin, the app can't protect it.")
            }
            .alert("Couldn't export", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
    }
}

/// System share sheet, presented by UIKit over the top-most screen. Wrapping it in a SwiftUI sheet made
/// its own dismissal close the sheet underneath too (e.g. Settings).
private enum ShareSheet {
    static func present(_ items: [URL]) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}
