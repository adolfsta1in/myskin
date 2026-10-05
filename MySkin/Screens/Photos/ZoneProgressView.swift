import SwiftData
import SwiftUI

/// Photos of one zone: before / after curtain, all photos, and a timeline with treatment starts.
struct ZoneProgressView: View {
    @Environment(\.modelContext) private var modelContext
    let zoneID: String
    @Query private var photos: [Photo]
    @Query private var treatments: [Treatment]

    @State private var curtain: CGFloat = 0.5
    @State private var beforeIndex = 0
    @State private var afterIndex = 0
    @State private var source: PhotoSource?
    @State private var photoToDelete: Photo?
    @State private var errorMessage: String?

    init(zoneID: String) {
        self.zoneID = zoneID
        _photos = Query(filter: #Predicate<Photo> { $0.zoneID == zoneID }, sort: \Photo.createdAt)
    }

    private var zoneName: String { BodyZone.zone(id: zoneID)?.name ?? "Area" }

    /// Treatments applied to this zone, by start date.
    private var markers: [(date: Date, title: String)] {
        treatments
            .filter { $0.zoneIDs.contains(zoneID) }
            .map { ($0.startDate, $0.name) }
            .sorted { $0.date < $1.date }
    }

    private var beforePhoto: Photo? { photos.indices.contains(beforeIndex) ? photos[beforeIndex] : nil }
    private var afterPhoto: Photo? { photos.indices.contains(afterIndex) ? photos[afterIndex] : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if photos.count >= 2 {
                    beforeAfter
                } else if let photo = photos.first {
                    StoredPhotoImage(fileName: photo.fileName, maxPixelSize: 1600, cornerRadius: Theme.cardRadius)
                        .aspectRatio(0.9, contentMode: .fit)
                    Text("Add another photo of this area to compare before and after.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text("No photos of this area yet.")
                        .font(.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .glassCard()
                }
                if !photos.isEmpty {
                    photoStrip
                    timeline
                }
                HStack(spacing: 12) {
                    ForEach(PhotoSource.available) { option in
                        if option == PhotoSource.available.first {
                            PrimaryButton(title: option.title, systemImage: option.systemImage) { source = option }
                        } else {
                            SecondaryButton(title: option.title) { source = option }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenScaffold()
        .navigationTitle(zoneName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(PhotoSource.available) { option in
                        Button(option.title, systemImage: option.systemImage) { source = option }
                    }
                } label: {
                    Label("Add photo", systemImage: "plus")
                }
            }
        }
        .photoImport(zoneID: zoneID, source: $source)
        .onAppear(perform: resetSelection)
        .onChange(of: photos.count) { resetSelection() }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: Binding(get: { photoToDelete != nil }, set: { if !$0 { photoToDelete = nil } }),
            titleVisibility: .visible,
            presenting: photoToDelete
        ) { photo in
            Button("Delete photo", role: .destructive) { delete(photo) }
        } message: { _ in
            Text("The photo is removed from MySkin for good.")
        }
        .alert("Couldn't delete the photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Oldest photo as «before», newest as «now».
    private func resetSelection() {
        beforeIndex = 0
        afterIndex = max(photos.count - 1, 0)
    }

    private func delete(_ photo: Photo) {
        guard let store = PhotoStore.shared else { return }
        do {
            try PhotoRecords.delete(photo, store: store, context: modelContext)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Before / after curtain

    private var beforeAfter: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                if let afterPhoto {
                    StoredPhotoImage(fileName: afterPhoto.fileName, maxPixelSize: 1600, cornerRadius: 0)
                }
                if let beforePhoto {
                    StoredPhotoImage(fileName: beforePhoto.fileName, maxPixelSize: 1600, cornerRadius: 0)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: width * curtain)
                        }
                }

                // Divider + handle
                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .offset(x: width * curtain - 1.5)
                Image(systemName: "arrow.left.and.right")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .offset(x: width * curtain - 24)

                VStack {
                    HStack {
                        dateBadge("Before", beforePhoto?.day)
                        Spacer()
                        dateBadge("Now", afterPhoto?.day)
                    }
                    Spacer()
                }
                .padding(12)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    curtain = min(max(value.location.x / width, 0.02), 0.98)
                }
            )
        }
        .aspectRatio(0.9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Before and after comparison")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: curtain = min(curtain + 0.1, 0.98)
            case .decrement: curtain = max(curtain - 0.1, 0.02)
            default: break
            }
        }
    }

    private func dateBadge(_ title: String, _ date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.rounded(.caption, weight: .semibold))
            Text(date?.formatted(.dateTime.month(.abbreviated).day()) ?? "—").font(.rounded(.caption2))
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Strip

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "All photos", subtitle: "Tap to set “before”. Touch and hold to set “now” or delete.")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.element.persistentModelID) { index, photo in
                        VStack(spacing: 6) {
                            StoredPhotoImage(fileName: photo.fileName, maxPixelSize: 200, cornerRadius: 14)
                                .frame(width: 64, height: 64)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(index == beforeIndex || index == afterIndex ? Theme.accent : .clear, lineWidth: 3)
                                }
                            Text(photo.day.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.rounded(.caption2))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .onTapGesture { withAnimation(.smooth) { beforeIndex = index } }
                        .contextMenu {
                            Button("Set as before", systemImage: "arrow.left.to.line") { beforeIndex = index }
                            Button("Set as now", systemImage: "arrow.right.to.line") { afterIndex = index }
                            Button("Delete photo", systemImage: "trash", role: .destructive) { photoToDelete = photo }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Photo from \(photo.day.formatted(date: .long, time: .omitted))")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .glassCard()
    }

    // MARK: Treatment timeline

    private var timeline: some View {
        let markers = markers
        let dates = photos.map(\.day) + markers.map(\.date)
        let start = dates.min() ?? .now
        let end = max(dates.max() ?? .now, .now)
        let span = max(end.timeIntervalSince(start), 1)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Timeline", subtitle: markers.isEmpty ? "Photos of this area" : "Photos and treatment starts")
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.sand)
                        .frame(height: 6)
                        .offset(y: 30)
                    ForEach(photos, id: \.persistentModelID) { photo in
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 10, height: 10)
                            .offset(x: width * photo.day.timeIntervalSince(start) / span - 5, y: 30)
                    }
                    ForEach(Array(markers.enumerated()), id: \.offset) { _, marker in
                        VStack(spacing: 4) {
                            Text(marker.title)
                                .font(.rounded(.caption2, weight: .semibold))
                                .foregroundStyle(Theme.sageDeep)
                                .lineLimit(1)
                                .frame(maxWidth: 110)
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.sageDeep)
                        }
                        .offset(x: width * max(marker.date.timeIntervalSince(start), 0) / span - 12, y: 0)
                    }
                }
            }
            .frame(height: 44)
            .accessibilityHidden(true)
            HStack {
                Text(start.formatted(.dateTime.month(.abbreviated).day()))
                Spacer()
                Text("Today")
            }
            .font(.rounded(.caption))
            .foregroundStyle(Theme.inkSoft)
        }
        .glassCard()
    }
}

#Preview {
    NavigationStack {
        ZoneProgressView(zoneID: "back.elbow.left")
    }
    .previewSetup()
}
