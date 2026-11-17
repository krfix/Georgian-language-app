import SwiftUI

/// A ring that fills as progress grows (daily goal, accuracy).
struct ProgressRing<Label: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var colors: [Color] = [Palette.gold, Palette.pomegranate]
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(AngularGradient(colors: colors + [colors.first ?? .clear], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motion(Motion.slow, value: progress)
            label
        }
    }
}

/// A thick rounded bar, for lesson progress and module completion.
struct ProgressBar: View {
    let progress: Double
    var color: Color = Palette.tkemali
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geo.size.width * min(1, max(0, progress))))
                    .overlay(alignment: .top) {
                        // A highlight along the top, like a glossy pill.
                        Capsule().fill(.white.opacity(0.35)).frame(height: height * 0.28).padding(.horizontal, height * 0.4).padding(.top, height * 0.18)
                    }
                    .opacity(progress <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .motion(Motion.spring, value: progress)
        .accessibilityElement()
        .accessibilityValue(tr("{0} percent", Int((progress * 100).rounded())))
    }
}
