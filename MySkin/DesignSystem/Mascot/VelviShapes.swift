import SwiftUI

/// Velvi's own colors, sampled from the character art. The mascot is the one place
/// outside `Theme` that defines colors — nothing else in the app should use these.
enum VelviPalette {
    static let skin = Color(hex: 0xFAC89C)
    static let shade = Color(hex: 0xF3B386)
    static let outline = Color(hex: 0xE5935F)
    static let leaf = Color(hex: 0xA3C49C)
    static let leafOutline = Color(hex: 0x6C9771)
    static let eye = Color(hex: 0x2A2421)
    static let cheek = Color(hex: 0xF5A797)
    static let spot = Color(hex: 0xF2A19D)
    static let tongue = Color(hex: 0xEE8F8A)
}

/// Every number that shapes Velvi's face, so a mood change morphs smoothly instead of
/// switching pictures. Stored in one SIMD vector to get `VectorArithmetic` for free.
nonisolated struct VelviFace: VectorArithmetic, Sendable {
    private var v = SIMD16<Double>(repeating: 0)

    /// Eye size in design units (the figure is 100 × 100).
    var eyeRadius: Double { get { v[0] } set { v[0] = newValue } }
    /// How far the upper lid bulges up, in eye radii: 1 = round, 0 = flat, < 0 = sags down.
    var eyeTop: Double { get { v[1] } set { v[1] = newValue } }
    /// How far the lower edge bulges down, in eye radii: 1 = round, < 0 = arched up (^^).
    var eyeBottom: Double { get { v[2] } set { v[2] = newValue } }
    var lookX: Double { get { v[3] } set { v[3] = newValue } }
    var lookY: Double { get { v[4] } set { v[4] = newValue } }
    var mouthWidth: Double { get { v[5] } set { v[5] = newValue } }
    /// Depth of the upper lip: > 0 smiles, < 0 arches up.
    var mouthCurve: Double { get { v[6] } set { v[6] = newValue } }
    /// Extra depth of the lower lip — an open mouth.
    var mouthOpen: Double { get { v[7] } set { v[7] = newValue } }
    var mouthShiftX: Double { get { v[8] } set { v[8] = newValue } }
    var browLift: Double { get { v[9] } set { v[9] = newValue } }
    /// > 0 lifts the inner ends (worried, caring), < 0 lowers them (focused).
    var browTilt: Double { get { v[10] } set { v[10] = newValue } }
    var browOpacity: Double { get { v[11] } set { v[11] = newValue } }
    var blush: Double { get { v[12] } set { v[12] = newValue } }
    /// Whole-body lean in degrees, around the bottom.
    var lean: Double { get { v[13] } set { v[13] = newValue } }
    /// Leaf angle in degrees, around the stem.
    var leafAngle: Double { get { v[14] } set { v[14] = newValue } }
    /// 1 = eyes as the mood wants, 0 = closed for a blink.
    var eyesOpen: Double { get { v[15] } set { v[15] = newValue } }

    init(
        eyeRadius: Double = 2.75, eyeTop: Double = 1, eyeBottom: Double = 1,
        lookX: Double = 0, lookY: Double = 0,
        mouthWidth: Double = 8.4, mouthCurve: Double = 2.6, mouthOpen: Double = 0, mouthShiftX: Double = 0,
        browLift: Double = 0, browTilt: Double = 0, browOpacity: Double = 0,
        blush: Double = 0.75, lean: Double = 0
    ) {
        self.eyeRadius = eyeRadius
        self.eyeTop = eyeTop
        self.eyeBottom = eyeBottom
        self.lookX = lookX
        self.lookY = lookY
        self.mouthWidth = mouthWidth
        self.mouthCurve = mouthCurve
        self.mouthOpen = mouthOpen
        self.mouthShiftX = mouthShiftX
        self.browLift = browLift
        self.browTilt = browTilt
        self.browOpacity = browOpacity
        self.blush = blush
        self.lean = lean
        self.eyesOpen = 1
    }

    private init(vector: SIMD16<Double>) { v = vector }

    static var zero: VelviFace { VelviFace(vector: .zero) }
    static func + (lhs: VelviFace, rhs: VelviFace) -> VelviFace { VelviFace(vector: lhs.v + rhs.v) }
    static func - (lhs: VelviFace, rhs: VelviFace) -> VelviFace { VelviFace(vector: lhs.v - rhs.v) }
    mutating func scale(by rhs: Double) { v *= rhs }
    var magnitudeSquared: Double { (v * v).sum() }
}

/// Draws Velvi into a `GraphicsContext`. All coordinates are in a 100 × 100 design space.
enum VelviDrawing {
    static let faceCenterX = 47.8
    static let eyeY = 55.0
    static let eyeXs = [35.0, 60.6]
    static let mouthY = 59.4
    /// Where the leaf meets the body — the leaf rotates around it.
    static let stem = CGPoint(x: 50, y: 24)

    static func draw(_ context: GraphicsContext, size: CGSize, face: VelviFace) {
        var ctx = context
        let scale = min(size.width, size.height) / 100
        ctx.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)

        // Lean around the bottom of the body.
        ctx.translateBy(x: 48, y: 97)
        ctx.rotate(by: .degrees(face.lean))
        ctx.translateBy(x: -48, y: -97)

        drawLeaf(ctx, angle: face.leafAngle)

        let body = bodyPath()
        ctx.fill(body, with: .color(VelviPalette.skin))

        var inside = ctx
        inside.clip(to: body)
        inside.fill(shadePath(), with: .color(VelviPalette.shade))
        drawSpots(inside)

        ctx.stroke(creasePath(), with: .color(VelviPalette.outline), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
        drawCheeks(ctx, face: face)
        drawEyes(ctx, face: face)
        drawBrows(ctx, face: face)
        drawMouth(ctx, face: face)

        ctx.stroke(body, with: .color(VelviPalette.outline), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
    }

    // MARK: Body

    static func bodyPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 25))
        p.addCurve(to: CGPoint(x: 28, y: 20.5), control1: CGPoint(x: 46, y: 21.5), control2: CGPoint(x: 37.5, y: 19.5))
        p.addCurve(to: CGPoint(x: 6.5, y: 50), control1: CGPoint(x: 15.5, y: 21.5), control2: CGPoint(x: 6.5, y: 33.5))
        p.addCurve(to: CGPoint(x: 48, y: 97.5), control1: CGPoint(x: 6.5, y: 74), control2: CGPoint(x: 25, y: 97.5))
        p.addCurve(to: CGPoint(x: 91, y: 54), control1: CGPoint(x: 72, y: 97.5), control2: CGPoint(x: 91, y: 80))
        p.addCurve(to: CGPoint(x: 68.5, y: 22), control1: CGPoint(x: 91, y: 35.5), control2: CGPoint(x: 82, y: 22.5))
        p.addCurve(to: CGPoint(x: 50, y: 25), control1: CGPoint(x: 59, y: 21.5), control2: CGPoint(x: 53, y: 22.5))
        p.closeSubpath()
        return p
    }

    /// The darker crescent along the lower right; drawn clipped to the body.
    static func shadePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 38, y: 100))
        p.addCurve(to: CGPoint(x: 92, y: 44), control1: CGPoint(x: 64, y: 91), control2: CGPoint(x: 88, y: 72))
        p.addLine(to: CGPoint(x: 110, y: 44))
        p.addLine(to: CGPoint(x: 110, y: 110))
        p.addLine(to: CGPoint(x: 38, y: 110))
        p.closeSubpath()
        return p
    }

    static func creasePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 50, y: 26))
        p.addQuadCurve(to: CGPoint(x: 44.5, y: 39.5), control: CGPoint(x: 45, y: 29.5))
        return p
    }

    // MARK: Leaf

    static func drawLeaf(_ context: GraphicsContext, angle: Double) {
        var ctx = context
        ctx.translateBy(x: stem.x, y: stem.y)
        ctx.rotate(by: .degrees(angle))
        ctx.translateBy(x: -stem.x, y: -stem.y)

        var leaf = Path()
        leaf.move(to: stem)
        leaf.addCurve(to: CGPoint(x: 82, y: 4.5), control1: CGPoint(x: 49.5, y: 8), control2: CGPoint(x: 63, y: 0.5))
        leaf.addCurve(to: stem, control1: CGPoint(x: 80, y: 17), control2: CGPoint(x: 63, y: 23))
        leaf.closeSubpath()
        ctx.fill(leaf, with: .color(VelviPalette.leaf))
        ctx.stroke(leaf, with: .color(VelviPalette.leafOutline), style: StrokeStyle(lineWidth: 1.25, lineJoin: .round))

        var vein = Path()
        vein.move(to: CGPoint(x: 57, y: 15.5))
        vein.addLine(to: CGPoint(x: 72, y: 7.5))
        ctx.stroke(vein, with: .color(VelviPalette.leafOutline), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
    }

    // MARK: Spots

    private struct Spot {
        let x: Double, y: Double, width: Double, height: Double, angle: Double, scales: Int
    }

    private static let spots = [
        Spot(x: 24.5, y: 34.5, width: 14, height: 9.5, angle: -28, scales: 3),
        Spot(x: 21.8, y: 74.5, width: 11, height: 7.5, angle: 38, scales: 2),
        Spot(x: 82, y: 64, width: 11.5, height: 8.5, angle: -62, scales: 3),
    ]

    private static func drawSpots(_ context: GraphicsContext) {
        for spot in spots {
            var ctx = context
            ctx.translateBy(x: spot.x, y: spot.y)
            ctx.rotate(by: .degrees(spot.angle))
            let w = spot.width, h = spot.height
            // Two overlapping blobs give the lumpy, plaque-like outline of the art.
            var blob = Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w * 0.72, height: h))
            blob.addEllipse(in: CGRect(x: -w / 2 + w * 0.3, y: -h / 2 + h * 0.08, width: w * 0.7, height: h * 0.86))
            ctx.fill(blob, with: .color(VelviPalette.spot))

            var scales = Path()
            let step = w * 0.24
            let first = -step * Double(spot.scales - 1) / 2
            for index in 0..<spot.scales {
                let x = first + step * Double(index)
                scales.move(to: CGPoint(x: x - 0.9, y: 1.2))
                scales.addLine(to: CGPoint(x: x + 0.9, y: -1.2))
            }
            ctx.stroke(scales, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
    }

    // MARK: Face

    private static func drawCheeks(_ context: GraphicsContext, face: VelviFace) {
        guard face.blush > 0.01 else { return }
        for x in [29.4, 66.0] {
            let cheek = Path(ellipseIn: CGRect(x: x - 4.9, y: 61.3 - 3.2, width: 9.8, height: 6.4))
            context.fill(cheek, with: .color(VelviPalette.cheek.opacity(min(face.blush, 1))))
        }
    }

    static func eyePath(centerX: Double, face: VelviFace) -> Path {
        let r = face.eyeRadius
        let open = min(max(face.eyesOpen, 0), 1)
        // A blink flattens the eye into a soft downward line.
        let top = face.eyeTop * open + (-0.15) * (1 - open)
        let bottom = face.eyeBottom * open + 0.3 * (1 - open)
        let cx = centerX + face.lookX
        let cy = eyeY + face.lookY
        let k = 4.0 / 3.0
        var p = Path()
        p.move(to: CGPoint(x: cx - r, y: cy))
        p.addCurve(
            to: CGPoint(x: cx + r, y: cy),
            control1: CGPoint(x: cx - r, y: cy - top * r * k),
            control2: CGPoint(x: cx + r, y: cy - top * r * k)
        )
        p.addCurve(
            to: CGPoint(x: cx - r, y: cy),
            control1: CGPoint(x: cx + r, y: cy + bottom * r * k),
            control2: CGPoint(x: cx - r, y: cy + bottom * r * k)
        )
        p.closeSubpath()
        return p
    }

    private static func drawEyes(_ context: GraphicsContext, face: VelviFace) {
        for x in eyeXs {
            let eye = eyePath(centerX: x, face: face)
            context.fill(eye, with: .color(VelviPalette.eye))
            // The stroke keeps closed eyes visible as a line.
            context.stroke(eye, with: .color(VelviPalette.eye), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
        }
    }

    private static func drawBrows(_ context: GraphicsContext, face: VelviFace) {
        guard face.browOpacity > 0.01 else { return }
        let y = eyeY - face.eyeRadius - 3.6 - face.browLift
        var brows = Path()
        // Left brow: its inner end is on the right.
        brows.move(to: CGPoint(x: eyeXs[0] - 2.4, y: y))
        brows.addLine(to: CGPoint(x: eyeXs[0] + 2.4, y: y - face.browTilt))
        brows.move(to: CGPoint(x: eyeXs[1] - 2.4, y: y - face.browTilt))
        brows.addLine(to: CGPoint(x: eyeXs[1] + 2.4, y: y))
        context.stroke(
            brows,
            with: .color(VelviPalette.eye.opacity(min(face.browOpacity, 1))),
            style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
        )
    }

    static func mouthPath(face: VelviFace) -> Path {
        let cx = faceCenterX + face.mouthShiftX
        let half = max(face.mouthWidth, 0.5) / 2
        var p = Path()
        p.move(to: CGPoint(x: cx - half, y: mouthY))
        p.addQuadCurve(to: CGPoint(x: cx + half, y: mouthY), control: CGPoint(x: cx, y: mouthY + 2 * face.mouthCurve))
        p.addQuadCurve(
            to: CGPoint(x: cx - half, y: mouthY),
            control: CGPoint(x: cx, y: mouthY + 2 * (face.mouthCurve + max(face.mouthOpen, 0)))
        )
        p.closeSubpath()
        return p
    }

    private static func drawMouth(_ context: GraphicsContext, face: VelviFace) {
        let mouth = mouthPath(face: face)
        context.fill(mouth, with: .color(VelviPalette.eye))
        if face.mouthOpen > 1.5 {
            var inside = context
            inside.clip(to: mouth)
            let cx = faceCenterX + face.mouthShiftX
            let depth = mouthY + face.mouthCurve + face.mouthOpen
            inside.fill(
                Path(ellipseIn: CGRect(x: cx - face.mouthWidth * 0.3, y: depth - 2.2, width: face.mouthWidth * 0.6, height: 4)),
                with: .color(VelviPalette.tongue)
            )
        }
        context.stroke(mouth, with: .color(VelviPalette.eye), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
    }
}
