import SwiftUI

// SwiftUI takes on interface studies from dqnamo's "Kitchen" (dqnamo.com/kitchen),
// restyled in ShopDoctor's white + green tokens. Every animation honours Reduce Motion.

// MARK: - Tactile button (Kitchen: Tactile Button)

/// A raised face on a darker edge that compresses when pressed.
struct TactileButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        TactileFace(label: configuration.label, pressed: configuration.isPressed, enabled: enabled)
    }
}

private struct TactileFace<Label: View>: View {
    let label: Label
    let pressed: Bool
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let depth: CGFloat = 5
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        let face = enabled ? Theme.primary : Theme.inkMuted.opacity(0.55)
        let edge = enabled ? Theme.primaryDark : Theme.inkMuted.opacity(0.8)
        ZStack(alignment: .top) {
            shape.fill(edge).offset(y: depth)
            label
                .font(Theme.headline())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    shape.fill(LinearGradient(colors: [face.opacity(0.88), face], startPoint: .top, endPoint: .bottom))
                )
                .overlay(shape.inset(by: 1).stroke(.white.opacity(0.28), lineWidth: 1).mask(
                    LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
                .offset(y: pressed && enabled ? depth - 1 : 0)
        }
        .frame(height: 50)
        .padding(.bottom, depth)
        .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.62), value: pressed)
        .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new && enabled }
    }
}

// MARK: - Hold to confirm (Kitchen: Hold to Confirm)

/// A destructive action that fills while held. Releasing early rolls the fill back.
struct HoldToConfirmButton: View {
    let label: String
    var duration: Double = 1.6
    let onConfirm: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var confirmed = false
    @State private var timer: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                shape.fill(Theme.critical.opacity(0.08))
                shape.stroke(Theme.critical.opacity(0.35))
                content(color: Theme.critical)
                // The filled layer reveals white text over red as it grows.
                Rectangle().fill(Theme.critical)
                    .overlay(content(color: .white).frame(width: geo.size.width), alignment: .leading)
                    .frame(width: geo.size.width * progress)
                    .clipped()
            }
            .clipShape(shape)
        }
        .frame(height: 46)
        .scaleEffect(holding ? 0.98 : 1)
        .animation(.easeOut(duration: 0.12), value: holding)
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !holding && !confirmed && progress == 0 { begin() }
                    if holding && hypot(value.translation.width, value.translation.height) > 40 { cancel() }
                }
                .onEnded { _ in if holding { cancel() } }
        )
        .sensoryFeedback(.success, trigger: confirmed) { _, new in new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(L("Press and hold to confirm"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { complete() }
    }

    private func content(color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: confirmed ? "checkmark" : "hand.tap")
            Text(confirmed ? L("Confirmed") : holding ? L("Keep holding…") : label)
        }
        .font(Theme.headline(15))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
    }

    private func begin() {
        holding = true
        withAnimation(reduceMotion ? nil : .linear(duration: duration)) { progress = 1 }
        timer = Task {
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled && holding { complete() }
        }
    }

    private func cancel() {
        holding = false
        timer?.cancel()
        withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)) { progress = 0 }
    }

    private func complete() {
        holding = false
        timer?.cancel()
        progress = 1
        confirmed = true
        onConfirm()
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            confirmed = false
            withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
        }
    }
}

/// The timed undo shown after a hold-to-confirm action (Kitchen: Hold to Confirm → undo notice).
struct UndoBar: View {
    let message: String
    var seconds: Double = 4
    let onUndo: () -> Void
    let onCommit: () -> Void
    @State private var remaining: CGFloat = 1

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 2.5)
                Circle().trim(from: 0, to: remaining).stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
            Text(message).font(Theme.body).foregroundStyle(.white)
            Spacer()
            Button(L("Undo"), action: onUndo).font(Theme.headline(15)).foregroundStyle(Theme.primarySoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Theme.ink.opacity(0.2), radius: 16, y: 6)
        .task {
            withAnimation(.linear(duration: seconds)) { remaining = 0 }
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { onCommit() }
        }
    }
}

// MARK: - Scramble text (Kitchen: Scramble Text)

/// Reveals text left to right through a field of scrambling symbols.
struct ScrambleText: View {
    let text: String
    var interval: Double = 0.032
    @State private var shown = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let symbols = Array("-_~`!@#$%^&*()+=[]{}|;:,.<>?")

    var body: some View {
        Text(shown.isEmpty ? text : shown)
            .accessibilityLabel(text)
            .task(id: text) { await run() }
    }

    private func run() async {
        let chars = Array(text)
        guard !reduceMotion, !chars.isEmpty else { shown = text; return }
        let steps = min(48, chars.count)
        for step in 0...steps {
            let revealed = Int((Double(step) / Double(steps) * Double(chars.count)).rounded(.up))
            shown = String(chars.enumerated().map { i, c in
                i < revealed || c.isWhitespace ? c : Self.symbols.randomElement()!
            })
            try? await Task.sleep(for: .seconds(interval))
            if Task.isCancelled { return }
        }
        shown = text
    }
}

// MARK: - Scroll fade (Kitchen: Scroll Fade List)

extension View {
    /// Softly fades content into the top and bottom edges of a scrolling surface.
    func scrollEdgeFade(_ length: CGFloat = 24) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: length)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: length)
            }
        }
    }
}

// MARK: - Cross trace loader (Kitchen: Logo Trace Loader)

/// A medical cross outline in unit space, with softly rounded corners.
struct MedicalCross: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
        let a = s / 3  // arm thickness
        let pts: [CGPoint] = [
            (a, 0), (2 * a, 0), (2 * a, a), (s, a), (s, 2 * a), (2 * a, 2 * a),
            (2 * a, s), (a, s), (a, 2 * a), (0, 2 * a), (0, a), (a, a),
        ].map { CGPoint(x: o.x + $0.0, y: o.y + $0.1) }
        var p = Path()
        let r = s * 0.06
        // Start halfway along the top edge so every corner can be rounded.
        p.move(to: CGPoint(x: (pts[0].x + pts[1].x) / 2, y: pts[0].y))
        for i in 1...pts.count {
            p.addArc(tangent1End: pts[i % pts.count], tangent2End: pts[(i + 1) % pts.count], radius: r)
        }
        p.closeSubpath()
        return p
    }
}

/// While `complete` is false a bright segment circles the cross; when it turns true the
/// outline closes, the cross fills in, and `onDone` fires once.
struct CrossTraceLoader: View {
    let complete: Bool
    var size: CGFloat = 96
    var loopSeconds: Double = 1.4
    let onDone: () -> Void

    @State private var closing: CGFloat = 0
    @State private var fill: Double = 0
    @State private var resolving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let line = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        ZStack {
            MedicalCross().stroke(Theme.primary.opacity(0.18), style: StrokeStyle(lineWidth: 2.5))
            if !resolving {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let head = CGFloat((t / loopSeconds).truncatingRemainder(dividingBy: 1))
                    let tail = head + 0.16
                    ZStack {
                        MedicalCross().trim(from: head, to: min(tail, 1)).stroke(Theme.primary, style: line)
                        if tail > 1 {
                            MedicalCross().trim(from: 0, to: tail - 1).stroke(Theme.primary, style: line)
                        }
                    }
                }
            }
            MedicalCross().trim(from: 0, to: closing).stroke(Theme.primary, style: line)
            MedicalCross().fill(Theme.primary).opacity(fill)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(complete ? L("Diagnosis ready") : L("Diagnosing"))
        .onChange(of: complete) { _, done in if done { resolve() } }
        .onAppear { if complete { resolve() } }
    }

    private func resolve() {
        guard !resolving else { return }
        resolving = true
        if reduceMotion {
            closing = 1
            fill = 1
            onDone()
            return
        }
        Task {
            withAnimation(.easeInOut(duration: 0.45)) { closing = 1 }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeOut(duration: 0.35)) { fill = 1 }
            try? await Task.sleep(for: .seconds(0.55))
            onDone()
        }
    }
}

// MARK: - Signature (Kitchen: Animated Signature)

/// "Dr. ShopDoctor" sign-off that draws itself.
struct DoctorSignature: Shape {
    func path(in rect: CGRect) -> Path {
        // Authored in a 300×100 box, then scaled to fit.
        var p = Path()
        p.move(to: .init(x: 18, y: 62))
        p.addCurve(to: .init(x: 46, y: 18), control1: .init(x: 6, y: 40), control2: .init(x: 26, y: 14))
        p.addCurve(to: .init(x: 30, y: 72), control1: .init(x: 70, y: 24), control2: .init(x: 58, y: 70))
        p.addCurve(to: .init(x: 62, y: 52), control1: .init(x: 14, y: 74), control2: .init(x: 40, y: 50))
        p.addCurve(to: .init(x: 84, y: 60), control1: .init(x: 72, y: 50), control2: .init(x: 76, y: 66))
        p.addCurve(to: .init(x: 104, y: 44), control1: .init(x: 92, y: 54), control2: .init(x: 96, y: 40))
        p.addCurve(to: .init(x: 116, y: 62), control1: .init(x: 112, y: 48), control2: .init(x: 104, y: 66))
        p.addCurve(to: .init(x: 138, y: 30), control1: .init(x: 128, y: 58), control2: .init(x: 130, y: 30))
        p.addCurve(to: .init(x: 140, y: 64), control1: .init(x: 146, y: 32), control2: .init(x: 134, y: 64))
        p.addCurve(to: .init(x: 170, y: 46), control1: .init(x: 150, y: 64), control2: .init(x: 158, y: 44))
        p.addCurve(to: .init(x: 176, y: 62), control1: .init(x: 182, y: 48), control2: .init(x: 166, y: 64))
        p.addCurve(to: .init(x: 204, y: 44), control1: .init(x: 188, y: 60), control2: .init(x: 194, y: 44))
        p.addCurve(to: .init(x: 222, y: 60), control1: .init(x: 214, y: 44), control2: .init(x: 212, y: 62))
        p.addCurve(to: .init(x: 248, y: 40), control1: .init(x: 232, y: 58), control2: .init(x: 238, y: 40))
        // Flourish underline
        p.addCurve(to: .init(x: 40, y: 84), control1: .init(x: 262, y: 42), control2: .init(x: 150, y: 96))
        p.addCurve(to: .init(x: 282, y: 76), control1: .init(x: 120, y: 78), control2: .init(x: 220, y: 70))
        let scale = min(rect.width / 300, rect.height / 100)
        return p.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}

struct SignatureView: View {
    var draw: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        DoctorSignature()
            .trim(from: 0, to: progress)
            .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .aspectRatio(3, contentMode: .fit)
            .onAppear { if draw { start() } }
            .onChange(of: draw) { _, d in if d { start() } }
            .accessibilityLabel(L("Signed, Dr. ShopDoctor"))
    }

    private func start() {
        guard progress == 0 else { return }
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.2, 0.8, 0.9, duration: 1.8)) { progress = 1 }
    }
}

// MARK: - Receipt paper (Kitchen: Receipt Printer)

/// Paper with a torn zigzag bottom edge.
struct ZigzagBottom: Shape {
    var teeth: Int = 28
    var depth: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: rect.minX, y: rect.minY))
        p.addLine(to: .init(x: rect.maxX, y: rect.minY))
        p.addLine(to: .init(x: rect.maxX, y: rect.maxY - depth))
        let w = rect.width / CGFloat(teeth)
        for i in (0..<teeth).reversed() {
            p.addLine(to: .init(x: rect.minX + w * (CGFloat(i) + 0.5), y: rect.maxY))
            p.addLine(to: .init(x: rect.minX + w * CGFloat(i), y: rect.maxY - depth))
        }
        p.closeSubpath()
        return p
    }
}
