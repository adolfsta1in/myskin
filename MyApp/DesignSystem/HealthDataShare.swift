import SwiftUI
import UIKit

extension View {
    /// Warns that the file contains health data, then builds it and opens the system share sheet.
    /// Old exports are removed before the next export and on launch (not on close: AirDrop may still be sending).
    func healthDataShare(isPresented: Binding<Bool>, makeFile: @escaping () throws -> URL) -> some View {
        modifier(HealthDataShare(isAsking: isPresented, makeFile: makeFile))
    }
}

private struct HealthDataShare: ViewModifier {
    @Binding var isAsking: Bool
    let makeFile: () throws -> URL
    @State private var file: SharedFile?
    @State private var error: String?

    struct SharedFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    func body(content: Content) -> some View {
        content
            .alert("This contains health data", isPresented: $isAsking) {
                Button("Continue") {
                    do {
                        file = SharedFile(url: try makeFile())
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only share it with people you trust, such as your doctor. Once it leaves MySkin, the app can't protect it.")
            }
            .sheet(item: $file) { file in
                ActivityView(items: [file.url])
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
