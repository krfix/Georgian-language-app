import SwiftUI

/// A burst of confetti in the brand colours, for finished lessons and achievements.
/// Drawn with Canvas; nothing is shown with Reduce Motion on.
struct ConfettiView: View {
    var count = 70
    var duration: Double = 2.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var pieces: [Piece] = []

    struct Piece {
        let x: Double, speed: Double, drift: Double, spin: Double, size: Double, delay: Double
        let color: Color
        let round: Bool
    }

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSince(start)
                    for p in pieces {
                        let life = t - p.delay
                        guard life > 0, life < duration else { continue }
                        let y = -20 + life * p.speed * size.height * 0.5 + 0.5 * 300 * life * life
                        let x = p.x * size.width + sin(life * 3 + p.drift) * 28
                        let fade = max(0, 1 - life / duration)
                        var c = ctx
                        c.opacity = fade
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(life * p.spin))
                        let rect = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.round ? p.size : p.size / 2)
                        c.fill(p.round ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2), with: .color(p.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                start = Date()
                let colors = [Palette.pomegranate, Palette.gold, Palette.saperavi, Palette.tkemali, Palette.blacksea]
                pieces = (0..<count).map { i in
                    Piece(x: Double.random(in: 0...1), speed: Double.random(in: 0.2...0.9), drift: Double.random(in: 0...6),
                          spin: Double.random(in: -8...8), size: Double.random(in: 7...13), delay: Double.random(in: 0...0.5),
                          color: colors[i % colors.count], round: i % 3 == 0)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
