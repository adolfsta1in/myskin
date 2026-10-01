import SwiftData
import SwiftUI

struct PhotosView: View {
    @Query(sort: \Photo.createdAt, order: .reverse) private var photos: [Photo]
    @State private var pendingSource: PhotoSource?
    @State private var isChoosingZone = false
    @State private var zoneID: String?
    @State private var source: PhotoSource?

    var body: some View {
        let zones = PhotoRecords.zonesWithPhotos(photos)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photos")
                            .font(.rounded(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text("Same angle, same distance — so change is easy to see.")
                            .font(.rounded(.subheadline))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.top, 12)

                    if zones.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(zones, id: \.zoneID) { zone in
                                zoneTile(zoneID: zone.zoneID, latest: zone.latest, count: zone.count)
                            }
                        }
                    }

                    Label("Photos are kept inside MySkin. They are not added to your photo library and are not included in device backups.", systemImage: "lock.fill")
                        .font(.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                        .glassCard(padding: 14)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .screenScaffold()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addMenu
                }
            }
            .sheet(isPresented: $isChoosingZone, onDismiss: {
                // Open the source only after the zone sheet has gone, so the two don't overlap.
                if zoneID != nil { source = pendingSource }
                pendingSource = nil
            }) {
                PhotoZonePicker { zone in zoneID = zone.id }
            }
            .photoImport(zoneID: zoneID, source: $source)
        }
    }

    private var addMenu: some View {
        Menu {
            ForEach(PhotoSource.available) { option in
                Button(option.title, systemImage: option.systemImage) { start(option) }
            }
        } label: {
            Label("Add photo", systemImage: "plus")
        }
    }

    private func start(_ option: PhotoSource) {
        zoneID = nil
        pendingSource = option
        isChoosingZone = true
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            SoftIllustration(systemImage: "camera", size: 120)
            Text("No photos yet")
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Photos of the same area over time make changes easier to see — for you and your doctor.")
                .font(.rounded(.subheadline))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            ForEach(PhotoSource.available) { option in
                if option == PhotoSource.available.first {
                    PrimaryButton(title: option.title, systemImage: option.systemImage) { start(option) }
                } else {
                    SecondaryButton(title: option.title) { start(option) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 24)
    }

    private func zoneTile(zoneID: String, latest: Photo, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            StoredPhotoImage(fileName: latest.fileName)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 2) {
                Text(BodyZone.zone(id: zoneID)?.name ?? "Other area")
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(count) photo\(count == 1 ? "" : "s") · \(latest.day.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard(padding: 10)
    }
}

#Preview("Photos") {
    PhotosView()
        .previewSetup()
}
