import SwiftUI

struct PhotosView: View {
    @Environment(AppStore.self) private var store
    @State private var cameraZone: PhotoZone?

    var body: some View {
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

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(store.photoZones) { zone in
                            NavigationLink {
                                ZoneProgressView(zone: zone)
                            } label: {
                                zoneTile(zone)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Label("Photos are stored only on this device and never appear in your shared photo library.", systemImage: "lock.fill")
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
                    Button {
                        cameraZone = store.photoZones.first
                    } label: {
                        Label("New photo", systemImage: "camera")
                    }
                }
            }
            .fullScreenCover(item: $cameraZone) { zone in
                CameraOverlayView(zoneName: zone.name)
            }
        }
    }

    private func zoneTile(_ zone: PhotoZone) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AbstractSkinPlaceholder(seed: zone.photos.last?.seed ?? 0, calmness: zone.photos.last?.calmness ?? 0.5, cornerRadius: 18)
                .aspectRatio(1, contentMode: .fit)
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(zone.photos.count) photos · \(zone.photos.last?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "—")")
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .glassCard(padding: 10)
    }
}

// MARK: - Camera with ghost overlay

struct CameraOverlayView: View {
    let zoneName: String
    @Environment(\.dismiss) private var dismiss
    @State private var ghostOpacity: Double = 0.45
    @State private var didCapture = false

    var body: some View {
        ZStack {
            // Viewfinder placeholder (no real camera in the prototype).
            LinearGradient(colors: [Color(hex: 0x2B2A26), Color(hex: 0x3E3A33), Color(hex: 0x24231F)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.sandDeep.opacity(0.35), .clear], center: .center, startRadius: 20, endRadius: 260)
                .ignoresSafeArea()

            // Ghost of the previous photo.
            GhostOutline()
                .stroke(.white.opacity(ghostOpacity), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 8]))
                .frame(width: 260, height: 360)
            GhostOutline()
                .fill(.white.opacity(ghostOpacity * 0.12))
                .frame(width: 260, height: 360)

            VStack(spacing: 14) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Close")

                    Spacer()

                    Text(zoneName)
                        .font(.rounded(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .glassEffect(.clear, in: .capsule)

                    Spacer()

                    lightIndicator
                }

                Text("Line up the outline and hold your phone at the same distance.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.clear, in: .rect(cornerRadius: 20))

                Spacer()

                HStack(spacing: 10) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.white.opacity(0.8))
                    Slider(value: $ghostOpacity, in: 0.1...0.9)
                        .tint(.white)
                    Text("Ghost")
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .glassEffect(.clear, in: .capsule)

                HStack {
                    AbstractSkinPlaceholder(seed: 3, calmness: 0.4, cornerRadius: 12)
                        .frame(width: 52, height: 52)
                        .accessibilityLabel("Previous photo")
                    Spacer()
                    Button {
                        withAnimation(.bouncy) { didCapture = true }
                    } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                            Circle().fill(.white).frame(width: 64, height: 64)
                                .scaleEffect(didCapture ? 0.85 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Take photo")
                    Spacer()
                    Button {} label: {
                        Image(systemName: "bolt.slash")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .frame(width: 52)
                    .accessibilityLabel("Flash off")
                }
            }
            .padding(20)

            if didCapture {
                Label("Saved privately on this device", systemImage: "checkmark.circle.fill")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.tint(Theme.sage.opacity(0.5)), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sensoryFeedback(.impact(weight: .medium), trigger: didCapture) { _, captured in captured }
        .task(id: didCapture) {
            // Hide the "saved" toast after a moment so the shutter can be used again.
            guard didCapture else { return }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.smooth) { didCapture = false }
        }
    }

    private var lightIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(Theme.intensityMild)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < 2 ? .white : .white.opacity(0.3))
                        .frame(width: 4, height: CGFloat(8 + index * 4))
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .glassEffect(.clear, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lighting: good")
    }
}

/// Stylised outline of a bent arm, standing in for the previous photo's contour.
struct GhostOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.30, y: 0))
        path.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.55),
                      control1: CGPoint(x: w * 0.22, y: h * 0.2),
                      control2: CGPoint(x: w * 0.12, y: h * 0.42))
        path.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.78),
                      control1: CGPoint(x: w * 0.30, y: h * 0.70),
                      control2: CGPoint(x: w * 0.42, y: h * 0.78))
        path.addLine(to: CGPoint(x: w, y: h * 0.80))
        path.addLine(to: CGPoint(x: w, y: h * 0.60))
        path.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.52),
                      control1: CGPoint(x: w * 0.80, y: h * 0.58),
                      control2: CGPoint(x: w * 0.60, y: h * 0.58))
        path.addCurve(to: CGPoint(x: w * 0.60, y: 0),
                      control1: CGPoint(x: w * 0.46, y: h * 0.36),
                      control2: CGPoint(x: w * 0.58, y: h * 0.2))
        path.closeSubpath()
        return path
    }
}

#Preview("Photos") {
    PhotosView()
        .previewSetup()
}

#Preview("Camera") {
    CameraOverlayView(zoneName: "Left elbow")
}
