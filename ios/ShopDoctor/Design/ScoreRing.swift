import SwiftUI

/// The Health Score "vital sign": a ring that fills to the score.
struct ScoreRing: View {
    let score: Double
    var size: CGFloat = 148
    var lineWidth: CGFloat = 14
    @State private var shown: Double = 0

    private var band: HealthBand { .forScore(score) }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.primarySoft, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown / 100)
                .stroke(
                    AngularGradient(colors: [band.color.opacity(0.65), band.color], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * shown / 100)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score.rounded()))")
                    .font(Theme.number(size * 0.32))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(L("of 100")).font(Theme.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { shown = score } }
        .onChange(of: score) { _, new in withAnimation(.easeOut(duration: 0.6)) { shown = new } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Health Score %lld out of 100, %@", Int(score), band.label))
    }
}

/// A slim horizontal meter for a 0–100 sub-score.
struct ScoreBar: View {
    let score: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface)
                Capsule().fill(HealthBand.forScore(score).color)
                    .frame(width: max(6, geo.size.width * score / 100))
            }
        }
        .frame(height: 6)
    }
}
