import PhotosUI
import SwiftData
import SwiftUI

/// Where a new zone photo comes from.
enum PhotoSource: Identifiable {
    case library

    var id: Self { self }

    var title: String {
        switch self {
        case .library: "Choose from library"
        }
    }

    var systemImage: String {
        switch self {
        case .library: "photo.on.rectangle"
        }
    }

    /// Sources this device offers.
    static var available: [PhotoSource] { [.library] }
}

/// Presents the photo picker for `zoneID` and stores the chosen image in `PhotoStore` + `Photo`.
/// The system picker runs out of process, so no photo library permission is needed,
/// and nothing is ever written back to the library.
struct PhotoImportModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let zoneID: String?
    @Binding var source: PhotoSource?

    @State private var item: PhotosPickerItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: Binding(get: { source == .library }, set: { if !$0 { source = nil } }),
                selection: $item,
                matching: .images,
                preferredItemEncoding: .compatible
            )
            .onChange(of: item) { _, newItem in
                guard let newItem, let zoneID else { return }
                item = nil
                Task { await importItem(newItem, zoneID: zoneID) }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving photo…")
                        .font(.rounded(.subheadline, weight: .medium))
                        .padding(20)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
            }
            .alert("Couldn't add the photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func importItem(_ item: PhotosPickerItem, zoneID: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoStore.PhotoError.unreadableImage }
            try await save(data, zoneID: zoneID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ data: Data, zoneID: String) async throws {
        guard let store = PhotoStore.shared else { throw PhotoStore.PhotoError.encodingFailed }
        try await PhotoRecords.add(imageData: data, zoneID: zoneID, store: store, context: modelContext)
    }
}

extension View {
    func photoImport(zoneID: String?, source: Binding<PhotoSource?>) -> some View {
        modifier(PhotoImportModifier(zoneID: zoneID, source: source))
    }
}

/// Zone list for a new photo, special areas first.
struct PhotoZonePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (BodyZone) -> Void

    private var sections: [(title: String, zones: [BodyZone])] {
        let quickIDs = Set(BodyZone.quickZones.map(\.id))
        return [
            ("Special areas", BodyZone.quickZones),
            ("Front", BodyZone.all.filter { $0.id.hasPrefix("front.") && !quickIDs.contains($0.id) }),
            ("Back", BodyZone.all.filter { $0.id.hasPrefix("back.") && !quickIDs.contains($0.id) }),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.zones) { zone in
                            Button(zone.name) {
                                dismiss()
                                onPick(zone)
                            }
                            .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WarmBackground())
            .navigationTitle("Which area?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .fontDesign(.rounded)
    }
}
