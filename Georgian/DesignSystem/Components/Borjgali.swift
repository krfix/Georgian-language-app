import SwiftUI

/// The borjgali: the ancient Georgian sun symbol, seven curved arms turning around a centre.
/// The app's emblem, drawn here (no image files).
struct BorjgaliShape: Shape {
    var arms = 7

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<arms {
            let a = Double(i) / Double(arms) * 2 * .pi
            func pt(_ radius: Double, _ angle: Double) -> CGPoint {
                CGPoint(x: c.x + CGFloat(cos(angle) * radius), y: c.y + CGFloat(sin(angle) * radius))
            }
            // Each arm leaves the centre, sweeps out and curls back: a comma shape.
            let start = pt(r * 0.16, a)
            let tip = pt(r * 0.98, a + 0.9)
            let back = pt(r * 0.16, a + 0.55)
            p.move(to: start)
            p.addQuadCurve(to: tip, control: pt(r * 0.95, a - 0.05))
            p.addQuadCurve(to: back, control: pt(r * 0.55, a + 1.05))
            p.closeSubpath()
        }
        p.addEllipse(in: CGRect(x: c.x - r * 0.2, y: c.y - r * 0.2, width: r * 0.4, height: r * 0.4))
        return p
    }
}

/// The emblem, slowly turning (still when Reduce Motion is on).
struct Borjgali: View {
    var size: CGFloat = 120
    var colors: [Color] = [Palette.gold, Palette.pomegranate, Palette.saperavi]
    var spinning = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !spinning || reduceMotion)) { context in
            let angle = spinning && !reduceMotion ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 40) / 40 * 360 : 0
            BorjgaliShape()
                .fill(AngularGradient(colors: colors + [colors[0]], center: .center))
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
