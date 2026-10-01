import SwiftUI

struct ZoneProgressView: View {
    let zone: PhotoZone
    @State private var curtain: CGFloat = 0.5
    @State private var beforeIndex = 0
    @State private var afterIndex: Int
    @State private var isShowingCamera = false
    @State private var isBuildingTimelapse = false

    init(zone: PhotoZone) {
        self.zone = zone
        _afterIndex = State(initialValue: max(zone.photos.count - 1, 0))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                beforeAfter
                photoStrip
                timeline
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.smooth) { isBuildingTimelapse.toggle() }
                    } label: {
                        Label(isBuildingTimelapse ? "Timelapse ready" : "Build timelapse", systemImage: isBuildingTimelapse ? "checkmark" : "film.stack")
                            .font(.rounded(.headline, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)

                    Button {
                        isShowingCamera = true
                    } label: {
                        Image(systemName: "camera")
                            .font(.headline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("New photo")
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenScaffold()
        .navigationTitle(zone.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraOverlayView(zoneName: zone.name)
        }
    }

    private var beforePhoto: PhotoEntry? { zone.photos.indices.contains(beforeIndex) ? zone.photos[beforeIndex] : nil }
    private var afterPhoto: PhotoEntry? { zone.photos.indices.contains(afterIndex) ? zone.photos[afterIndex] : nil }

    // MARK: Before / after curtain

    private var beforeAfter: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                AbstractSkinPlaceholder(seed: afterPhoto?.seed ?? 0, calmness: afterPhoto?.calmness ?? 0.8, cornerRadius: 0)
                AbstractSkinPlaceholder(seed: beforePhoto?.seed ?? 1, calmness: beforePhoto?.calmness ?? 0.2, cornerRadius: 0)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * curtain)
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
                        dateBadge("Before", beforePhoto?.date)
                        Spacer()
                        dateBadge("Now", afterPhoto?.date)
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
            SectionHeader(title: "All photos", subtitle: "Tap to set “before”, long-press to set “now”")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(zone.photos.enumerated()), id: \.element.id) { index, photo in
                        VStack(spacing: 6) {
                            AbstractSkinPlaceholder(seed: photo.seed, calmness: photo.calmness, cornerRadius: 14)
                                .frame(width: 64, height: 64)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(index == beforeIndex || index == afterIndex ? Theme.accent : .clear, lineWidth: 3)
                                }
                            Text(photo.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.rounded(.caption2))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .onTapGesture { withAnimation(.smooth) { beforeIndex = index } }
                        .onLongPressGesture { withAnimation(.smooth) { afterIndex = index } }
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
        let dates = zone.photos.map(\.date) + zone.treatmentMarkers.map(\.date)
        let start = dates.min() ?? .now
        let end = max(dates.max() ?? .now, .now)
        let span = max(end.timeIntervalSince(start), 1)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Timeline", subtitle: "Photos and treatment changes")
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.sand)
                        .frame(height: 6)
                        .offset(y: 30)
                    ForEach(zone.photos) { photo in
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 10, height: 10)
                            .offset(x: width * photo.date.timeIntervalSince(start) / span - 5, y: 30)
                    }
                    ForEach(zone.treatmentMarkers) { marker in
                        VStack(spacing: 4) {
                            Text(marker.title)
                                .font(.rounded(.caption2, weight: .semibold))
                                .foregroundStyle(Theme.sageDeep)
                                .fixedSize()
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.sageDeep)
                        }
                        .offset(x: width * marker.date.timeIntervalSince(start) / span - 12, y: 0)
                    }
                }
            }
            .frame(height: 44)
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
        ZoneProgressView(zone: AppStore.preview.photoZones[0])
    }
    .previewSetup()
}
