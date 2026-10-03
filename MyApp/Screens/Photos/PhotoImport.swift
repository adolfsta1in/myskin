import PhotosUI
import SwiftData
import SwiftUI

/// Where a new zone photo comes from.
enum PhotoSource: Identifiable {
    case camera
    case library

    var id: Self { self }

    var title: String {
        switch self {
        case .camera: "Take photo"
        case .library: "Choose from library"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: "camera"
        case .library: "photo.on.rectangle"
        }
    }

    /// Sources this device offers; the camera is hidden where there is none (simulator).
    static var available: [PhotoSource] { CameraPicker.isAvailable ? [.camera, .library] : [.library] }
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
            .fullScreenCover(isPresented: Binding(get: { source == .camera }, set: { if !$0 { source = nil } })) {
                CameraPicker(
                    onCapture: { image in
                        source = nil
                        guard let zoneID, let data = image.jpegData(compressionQuality: 0.95) else { return }
                        Task { await importData(data, zoneID: zoneID) }
                    },
                    onCancel: { source = nil }
                )
                .ignoresSafeArea()
            }
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

    private func importData(_ data: Data, zoneID: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
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

/// Body map for choosing the area of a new photo: tap the silhouette or a special area.
/// Areas that already have photos are tinted.
struct PhotoZonePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [Photo]
    @State private var side: BodySide = .front
    let onPick: (BodyZone) -> Void

    /// Level 1 tint on zones with photos, so the user sees what's already covered.
    private var covered: [String: Int] {
        var levels: [String: Int] = [:]
        for photo in photos { levels[photo.zoneID] = 1 }
        // The silhouette's face shows photos filed under the special «Face» area.
        if levels["quick.face"] != nil { levels["front.head"] = 1 }
        return levels
    }

    var body: some View {
        let covered = covered
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Side", selection: $side) {
                        ForEach(BodySide.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    VStack(spacing: 10) {
                        BodySilhouette(side: side, intensities: covered) { zone in
                            pick(zone)
                        }
                        .containerRelativeFrame(.vertical) { height, _ in min(max(height * 0.5, 300), 460) }
                        .id(side)
                        .transition(.opacity)
                        Text("Tap the area you're photographing")
                            .font(.rounded(.footnote, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .animation(.smooth, value: side)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Special areas", subtitle: "Hard to point at on the map")
                        GlassEffectContainer(spacing: 8) {
                            FlowLayout(spacing: 8) {
                                ForEach(BodyZone.quickZones) { zone in
                                    TagChip(title: zone.name, systemImage: covered[zone.id] == nil ? nil : "photo", isSelected: false) {
                                        pick(zone)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
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

    private func pick(_ zone: BodyZone) {
        dismiss()
        onPick(PhotoRecords.photoZone(for: zone))
    }
}
