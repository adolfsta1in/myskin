import SwiftUI

/// How Velvi feels. Each mood is a set of face parameters, so switching moods morphs the face.
enum VelviMood: String, CaseIterable, Identifiable, Sendable {
    case happy
    case joyful
    case curious
    case thinking
    case caring
    case calm
    case sleepy
    case proud

    var id: String { rawValue }

    var face: VelviFace {
        switch self {
        case .happy:
            VelviFace()
        case .joyful:
            VelviFace(eyeRadius: 3, eyeBottom: -0.5, mouthWidth: 10, mouthCurve: 1.6, mouthOpen: 4.2, blush: 1)
        case .curious:
            VelviFace(
                eyeRadius: 3.1, lookX: 0.6, lookY: -0.3, mouthWidth: 4.5, mouthCurve: 1.4,
                browLift: 1.6, browTilt: 0.3, browOpacity: 1, blush: 0.6, lean: 7
            )
        case .thinking:
            VelviFace(
                lookX: 1.1, lookY: -1.1, mouthWidth: 3.2, mouthCurve: -1.1, mouthOpen: 2.2, mouthShiftX: 2.5,
                browLift: 1.4, browTilt: 0.6, browOpacity: 0.9, blush: 0.5, lean: -6
            )
        case .caring:
            VelviFace(
                eyeTop: 0.45, lookY: 0.3, mouthWidth: 6, mouthCurve: 1.2,
                browLift: 0.4, browTilt: 1.4, browOpacity: 1, blush: 0.8, lean: 4
            )
        case .calm:
            VelviFace(eyeTop: 0.25, mouthWidth: 6, mouthCurve: 1.8, blush: 0.7)
        case .sleepy:
            VelviFace(eyeRadius: 2.8, eyeTop: -0.4, eyeBottom: 0.75, mouthWidth: 3.6, mouthCurve: 0.8, blush: 0.6, lean: -5)
        case .proud:
            VelviFace(
                eyeRadius: 2.9, eyeBottom: -0.5, mouthWidth: 9, mouthCurve: 3, mouthOpen: 1.2, blush: 1, lean: -3
            )
        }
    }
}

/// Something Velvi holds up next to itself.
enum VelviProp: String, CaseIterable, Identifiable, Sendable {
    case report
    case bell
    case lock
    case heart
    case star

    var id: String { rawValue }
}

/// A one-shot reaction, played each time the mascot's `trigger` changes.
enum VelviMotion: String, CaseIterable, Identifiable, Sendable {
    /// Squash, jump, land — joy, a step forward.
    case hop
    /// Side-to-side sway — playful.
    case wiggle
    /// Two small dips — «got it».
    case nod
    /// Waves its leaf — hello.
    case wave

    var id: String { rawValue }
}

/// Velvi, the peach mascot. Decorative: whatever it says must also be said by text nearby.
///
/// Breathes, blinks and sways its leaf while on screen; plays `motion` when `trigger` changes.
/// With Reduce Motion it stands still and mood changes are a short fade.
struct VelviMascot: View {
    var mood: VelviMood = .happy
    var prop: VelviProp?
    var size: CGFloat = 120
    var motion: VelviMotion = .hop
    var trigger: Int = 0
    /// Off for screens that should stay still (a lock screen, an error).
    var isIdle = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinking = false

    private var isAnimated: Bool { isIdle && !reduceMotion }

    var body: some View {
        KeyframeAnimator(initialValue: VelviMotionValue(), trigger: reduceMotion ? 0 : trigger) { value in
            idleLayer(value)
                .scaleEffect(x: value.scaleX, y: value.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(value.angle), anchor: .bottom)
                .offset(y: value.y * size / 100)
        } keyframes: { _ in
            VelviMotionValue.keyframes(for: motion)
        }
        .frame(width: size, height: size)
        .task(id: isAnimated) { await blink() }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func idleLayer(_ value: VelviMotionValue) -> some View {
        if isAnimated {
            PhaseAnimator([false, true]) { inhale in
                figure(leafSway: inhale ? 4 : -3, value: value)
                    .scaleEffect(x: inhale ? 0.99 : 1, y: inhale ? 1.025 : 1, anchor: .bottom)
            } animation: { _ in
                .easeInOut(duration: 1.8)
            }
        } else {
            figure(leafSway: 0, value: value)
        }
    }

    private func figure(leafSway: Double, value: VelviMotionValue) -> some View {
        var face = mood.face
        face.leafAngle = leafSway + value.leaf
        face.eyesOpen = isBlinking ? 0 : 1
        return VelviFigure(face: face)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.35), value: mood)
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if let prop {
                    VelviPropView(prop: prop)
                        .frame(width: size * 0.36, height: size * 0.36)
                        .rotationEffect(.degrees(leafSway * 1.5))
                        .offset(x: size * 0.08, y: -size * 0.02)
                        .transition(.scale(scale: 0.4, anchor: .bottomLeading).combined(with: .opacity))
                        .id(prop)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.4), value: prop)
    }

    private func blink() async {
        guard isAnimated else {
            isBlinking = false
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.07)) { isBlinking = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.1)) { isBlinking = false }
        }
    }
}

/// The drawn character; animatable, so face parameters interpolate frame by frame.
private struct VelviFigure: View, Animatable {
    var face: VelviFace

    var animatableData: VelviFace {
        get { face }
        set { face = newValue }
    }

    var body: some View {
        Canvas { context, size in
            VelviDrawing.draw(context, size: size, face: face)
        }
    }
}

/// Transform applied during a reaction. `y` is in design units (the figure is 100 tall).
nonisolated struct VelviMotionValue {
    var y = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
    var angle = 0.0
    var leaf = 0.0

    /// One track per property; each track picks its keyframes for the motion.
    /// A motion that leaves a property alone just holds it at rest.
    @KeyframesBuilder<VelviMotionValue>
    static func keyframes(for motion: VelviMotion) -> some Keyframes<VelviMotionValue> {
        KeyframeTrack(\.y) {
            switch motion {
            case .hop:
                LinearKeyframe(0, duration: 0.1)
                CubicKeyframe(-18, duration: 0.22)
                CubicKeyframe(0, duration: 0.2)
                CubicKeyframe(-3, duration: 0.12)
                CubicKeyframe(0, duration: 0.12)
            case .nod:
                CubicKeyframe(2.5, duration: 0.14)
                CubicKeyframe(0, duration: 0.18)
                CubicKeyframe(2, duration: 0.14)
                CubicKeyframe(0, duration: 0.18)
            case .wave:
                CubicKeyframe(-2, duration: 0.25)
                CubicKeyframe(0, duration: 0.3)
            case .wiggle:
                MoveKeyframe(0)
            }
        }
        KeyframeTrack(\.scaleY) {
            switch motion {
            case .hop:
                CubicKeyframe(0.86, duration: 0.1)
                CubicKeyframe(1.1, duration: 0.12)
                CubicKeyframe(1, duration: 0.3)
                CubicKeyframe(0.9, duration: 0.08)
                CubicKeyframe(1.03, duration: 0.12)
                CubicKeyframe(1, duration: 0.12)
            case .nod:
                CubicKeyframe(0.95, duration: 0.14)
                CubicKeyframe(1, duration: 0.18)
                CubicKeyframe(0.96, duration: 0.14)
                CubicKeyframe(1, duration: 0.18)
            case .wiggle, .wave:
                MoveKeyframe(1)
            }
        }
        KeyframeTrack(\.scaleX) {
            switch motion {
            case .hop:
                CubicKeyframe(1.1, duration: 0.1)
                CubicKeyframe(0.93, duration: 0.12)
                CubicKeyframe(1, duration: 0.3)
                CubicKeyframe(1.08, duration: 0.08)
                CubicKeyframe(0.98, duration: 0.12)
                CubicKeyframe(1, duration: 0.12)
            case .nod, .wiggle, .wave:
                MoveKeyframe(1)
            }
        }
        KeyframeTrack(\.angle) {
            switch motion {
            case .wiggle:
                CubicKeyframe(7, duration: 0.12)
                CubicKeyframe(-7, duration: 0.14)
                CubicKeyframe(5, duration: 0.12)
                CubicKeyframe(-3, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
            case .wave:
                CubicKeyframe(5, duration: 0.3)
                CubicKeyframe(3, duration: 0.6)
                CubicKeyframe(0, duration: 0.4)
            case .hop, .nod:
                MoveKeyframe(0)
            }
        }
        KeyframeTrack(\.leaf) {
            switch motion {
            case .hop:
                LinearKeyframe(0, duration: 0.1)
                CubicKeyframe(-12, duration: 0.2)
                CubicKeyframe(10, duration: 0.2)
                CubicKeyframe(-4, duration: 0.15)
                CubicKeyframe(0, duration: 0.15)
            case .wiggle:
                CubicKeyframe(-8, duration: 0.12)
                CubicKeyframe(8, duration: 0.14)
                CubicKeyframe(-5, duration: 0.12)
                CubicKeyframe(0, duration: 0.2)
            case .wave:
                CubicKeyframe(28, duration: 0.2)
                CubicKeyframe(-6, duration: 0.18)
                CubicKeyframe(28, duration: 0.18)
                CubicKeyframe(-6, duration: 0.18)
                CubicKeyframe(24, duration: 0.18)
                CubicKeyframe(0, duration: 0.3)
            case .nod:
                MoveKeyframe(0)
            }
        }
    }
}

/// A small badge Velvi holds: a report sheet or a symbol in a round tag.
private struct VelviPropView: View {
    let prop: VelviProp

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Group {
                if prop == .report {
                    report(side: side)
                } else {
                    symbol(side: side)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func report(side: CGFloat) -> some View {
        let line = side * 0.05
        return RoundedRectangle(cornerRadius: side * 0.1, style: .continuous)
            .fill(.white)
            .overlay {
                VStack(alignment: .leading, spacing: side * 0.07) {
                    Capsule().fill(Theme.inkSoft.opacity(0.5)).frame(width: side * 0.4, height: line)
                    Capsule().fill(Theme.inkSoft.opacity(0.3)).frame(width: side * 0.3, height: line)
                    ReportSparkline()
                        .stroke(Theme.sageDeep, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                        .frame(height: side * 0.28)
                }
                .padding(side * 0.12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.1, style: .continuous)
                    .stroke(VelviPalette.outline, lineWidth: side * 0.045)
            }
            .frame(width: side * 0.78, height: side * 0.95)
            .rotationEffect(.degrees(8))
    }

    private func symbol(side: CGFloat) -> some View {
        Circle()
            .fill(Theme.cream)
            .overlay { Circle().stroke(VelviPalette.outline, lineWidth: side * 0.045) }
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: side * 0.46, weight: .semibold, design: .rounded))
                    .foregroundStyle(symbolColor)
            }
            .frame(width: side * 0.86, height: side * 0.86)
    }

    private var symbolName: String {
        switch prop {
        case .report: "doc.text"
        case .bell: "bell.fill"
        case .lock: "lock.fill"
        case .heart: "heart.fill"
        case .star: "star.fill"
        }
    }

    private var symbolColor: Color {
        switch prop {
        case .report: Theme.ink
        case .bell: Theme.accent
        case .lock: Theme.sageDeep
        case .heart: VelviPalette.cheek
        case .star: Theme.intensityModerate
        }
    }
}

/// A falling line, like an itch chart getting better.
nonisolated private struct ReportSparkline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.1))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.45))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.6, y: rect.minY + rect.height * 0.3))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

#if DEBUG
#Preview("Moods") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 16) {
        ForEach(VelviMood.allCases) { mood in
            VStack(spacing: 4) {
                VelviMascot(mood: mood, size: 100, isIdle: false)
                Text(verbatim: mood.rawValue)
                    .font(.rounded(.caption))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        ForEach(VelviProp.allCases) { prop in
            VelviMascot(mood: .happy, prop: prop, size: 100, isIdle: false)
        }
    }
    .padding()
    .background(WarmBackground())
    .previewSetup()
}
#endif
