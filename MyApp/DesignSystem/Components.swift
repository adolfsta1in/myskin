import SwiftUI

// MARK: - Glass card

/// Rounded Liquid Glass card used throughout the app.
struct GlassCard: ViewModifier {
    var padding: CGFloat = 20
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(tint?.opacity(0.28)), in: .rect(cornerRadius: Theme.cardRadius))
    }
}

extension View {
    func glassCard(padding: CGFloat = 20, tint: Color? = nil) -> some View {
        modifier(GlassCard(padding: padding, tint: tint))
    }

    /// Standard scroll-screen setup: warm background, room for the floating tab bar,
    /// keyboard dismissal on scroll.
    func screenScaffold() -> some View {
        self
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 24, for: .scrollContent)
            .background(WarmBackground())
    }
}

// MARK: - Text helpers

struct SectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Theme.accent)
                }
                Text(title)
                    .font(.rounded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Small "Why we ask" line shown under onboarding questions.
struct WhyWeAskText: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
            Text("\(Text("Why we ask:").fontWeight(.semibold)) \(text)")
        }
        .font(.rounded(.footnote))
        .foregroundStyle(Theme.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chips

struct TagChip: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.rounded(.subheadline, weight: .medium))
            .foregroundStyle(isSelected ? Theme.ink : Theme.ink.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(
                isSelected ? .regular.tint(Theme.accent.opacity(0.35)).interactive() : .regular.interactive(),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return CGSize(width: proposal.width ?? usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(.rounded(.headline, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.accent)
        .controlSize(.large)
    }
}

struct SecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(.headline, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

// MARK: - Placeholders & illustrations

/// Neutral abstract stand-in for a skin photo. Never depicts real skin.
/// `calmness` 0 = more intense soft patches, 1 = calm.
struct AbstractSkinPlaceholder: View {
    var seed: Int = 0
    var calmness: Double = 0.5
    var cornerRadius: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [Theme.sand, Theme.creamDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                // Soft patches drawn with radial gradients instead of blur (much cheaper).
                ForEach(0..<4, id: \.self) { index in
                    let offset = pseudoRandom(index)
                    let size = max(w, h) * (0.35 + offset.0 * 0.35) * (1.2 - calmness * 0.6)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [patchColor.opacity(0.6 * (1 - calmness) + 0.12), patchColor.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: size / 2
                            )
                        )
                        .frame(width: size, height: size)
                        .position(x: w * (0.2 + offset.0 * 0.6), y: h * (0.2 + offset.1 * 0.6))
                }
                Image(systemName: "photo")
                    .font(.system(size: min(w, h) * 0.16, weight: .light))
                    .foregroundStyle(Theme.inkSoft.opacity(0.35))
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
        // Static artwork: rasterize once into a single layer.
        .drawingGroup()
        .accessibilityLabel("Photo placeholder")
    }

    private var patchColor: Color {
        calmness > 0.6 ? Theme.intensityMild : Theme.intensityModerate
    }

    /// Deterministic pseudo random pair in 0...1 based on seed and index.
    private func pseudoRandom(_ index: Int) -> (Double, Double) {
        let a = sin(Double(seed * 31 + index * 17) * 12.9898) * 43758.5453
        let b = sin(Double(seed * 13 + index * 29) * 78.233) * 12345.6789
        return (a - a.rounded(.down), b - b.rounded(.down))
    }
}

/// Soft circular illustration with an SF Symbol, used instead of any skin imagery.
struct SoftIllustration: View {
    let systemImage: String
    var size: CGFloat = 160
    var tint: Color = Theme.sage

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: size, height: size)
            Circle()
                .fill(tint.opacity(0.35))
                .frame(width: size * 0.72, height: size * 0.72)
                .offset(x: size * 0.12, y: -size * 0.08)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.32, weight: .light))
                .foregroundStyle(Theme.sageDeep)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
