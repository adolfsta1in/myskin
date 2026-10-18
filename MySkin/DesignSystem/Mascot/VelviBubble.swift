import SwiftUI

/// A short line from Velvi in a glass speech bubble. The tail points at the mascot.
struct VelviBubble: View {
    nonisolated enum Tail: Sendable {
        /// Mascot to the left of the bubble.
        case leading
        /// Mascot below the bubble.
        case bottom
        /// Mascot above the bubble, near its leading edge.
        case top
        /// Mascot above the bubble, near its trailing edge.
        case topTrailing
    }

    let text: Text
    var tail: Tail = .leading

    private static let tailSize: CGFloat = 8

    init(_ text: LocalizedStringResource, tail: Tail = .leading) {
        self.text = Text(text)
        self.tail = tail
    }

    @_disfavoredOverload
    init(_ text: String, tail: Tail = .leading) {
        self.text = Text(verbatim: text)
        self.tail = tail
    }

    var body: some View {
        text
            .font(.rounded(.subheadline, weight: .medium))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .padding(tailEdge, Self.tailSize)
            .glassEffect(.regular, in: BubbleShape(tail: tail, tailSize: Self.tailSize))
    }

    private var tailEdge: Edge.Set {
        switch tail {
        case .leading: .leading
        case .bottom: .bottom
        case .top, .topTrailing: .top
        }
    }
}

/// Rounded rectangle with a small tail, one continuous outline so the glass has no seam.
/// The tail sits in the bubble's padding on the tail side.
nonisolated private struct BubbleShape: Shape {
    let tail: VelviBubble.Tail
    let tailSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var body = rect
        switch tail {
        case .leading:
            body.origin.x += tailSize
            body.size.width -= tailSize
        case .bottom:
            body.size.height -= tailSize
        case .top, .topTrailing:
            body.origin.y += tailSize
            body.size.height -= tailSize
        }
        let r = min(18, body.height / 2, body.width / 2)
        let t = tailSize
        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        if tail == .top || tail == .topTrailing {
            let x = tail == .top ? body.minX + min(32, body.width / 2) : body.maxX - min(32, body.width / 2)
            p.addLine(to: CGPoint(x: x - t, y: body.minY))
            p.addQuadCurve(to: CGPoint(x: x - t * 0.4, y: rect.minY), control: CGPoint(x: x - t * 0.5, y: body.minY - t * 0.3))
            p.addLine(to: CGPoint(x: x + t * 0.6, y: body.minY))
        }
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY), radius: r)
        if tail == .bottom {
            let x = body.minX + min(32, body.width / 2)
            p.addLine(to: CGPoint(x: x + t * 0.6, y: body.maxY))
            p.addLine(to: CGPoint(x: x - t * 0.4, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: x - t, y: body.maxY), control: CGPoint(x: x - t * 0.5, y: body.maxY + t * 0.3))
        }
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.minY), radius: r)
        if tail == .leading {
            let y = body.maxY - min(22, body.height / 2)
            p.addLine(to: CGPoint(x: body.minX, y: y + t * 0.6))
            p.addLine(to: CGPoint(x: rect.minX, y: y + t * 0.4))
            p.addQuadCurve(to: CGPoint(x: body.minX, y: y - t), control: CGPoint(x: body.minX - t * 0.3, y: y - t * 0.5))
        }
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        HStack(alignment: .bottom, spacing: 4) {
            VelviMascot(mood: .joyful, size: 72)
            VelviBubble("Logged. See you tomorrow." as String)
        }
        VStack(alignment: .leading, spacing: 4) {
            VelviBubble("That sounds tough. It's in your diary." as String, tail: .bottom)
            VelviMascot(mood: .caring, size: 72)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(WarmBackground())
    .previewSetup()
}
#endif
