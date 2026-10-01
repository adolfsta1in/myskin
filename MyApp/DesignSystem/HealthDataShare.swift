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
    @State private var files: SharedFiles?
    @State private var error: String?

    struct SharedFiles: Identifiable {
        let id = UUID()
        let urls: [URL]
    }

    func body(content: Content) -> some View {
        content
            .alert("This contains health data", isPresented: $isAsking) {
                Button("Continue") {
                    do {
                        files = SharedFiles(urls: try makeFiles())
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only share it with people you trust, such as your doctor. Once it leaves MySkin, the app can't protect it.")
            }
            .sheet(item: $files) { files in
                ActivityView(items: files.urls)
                    .presentationDetents([.medium, .large])
            }
            .alert("Couldn't export", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
    }
}

/// System share sheet for files.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
