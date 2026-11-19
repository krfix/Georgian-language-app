import SwiftUI

/// A stage's picture: its emoji, except the first stage, "Just landed", which gets Ara's own
/// twin-engine airliner (the ✈️ emoji is drawn by Apple, with four engines; owner, KART #8).
struct StageEmoji: View {
    let stage: CourseStage
    var size: CGFloat

    var body: some View {
        if stage.id == 0 {
            TwinJet().frame(width: size * 1.15, height: size * 1.15)
        } else {
            Text(stage.emoji).font(.system(size: size))
        }
    }
}

/// A twin-engine airliner seen from above, nose up and to the right like the emoji: drawn
/// on a 100 × 100 grid, silver body, Black Sea blue engines, a pomegranate tail.
struct TwinJet: View {
    private let body1 = Color(hex: 0xEEF2F6)
    private let wing = Color(hex: 0xC3CDD8)
    private let edge = Color(hex: 0x7B8896)

    var body: some View {
        ZStack {
            JetPart(points: Self.wings).fill(wing)
            JetPart(points: Self.wings).stroke(edge, lineWidth: 1.2)
            JetPart(points: Self.tailplane).fill(wing)
            JetPart(points: Self.tailplane).stroke(edge, lineWidth: 1.2)
            JetPart(capsules: Self.engines).fill(Palette.blacksea)
            JetPart(capsules: Self.engines).stroke(edge, lineWidth: 1)
            JetPart(capsules: [Self.fuselage]).fill(body1)
            JetPart(capsules: [Self.fuselage]).stroke(edge, lineWidth: 1.2)
            JetPart(capsules: [Self.fin]).fill(Palette.pomegranate)
            JetPart(capsules: [Self.cockpit]).fill(Color(hex: 0x2B3A4A))
        }
        .rotationEffect(.degrees(45))
        .accessibilityHidden(true)
    }

    // Swept wings and tailplane, left and right (x, y on the 100 grid).
    static let wings: [[CGPoint]] = [
        [CGPoint(x: 46, y: 38), CGPoint(x: 6, y: 58), CGPoint(x: 6, y: 64), CGPoint(x: 46, y: 54)],
        [CGPoint(x: 54, y: 38), CGPoint(x: 94, y: 58), CGPoint(x: 94, y: 64), CGPoint(x: 54, y: 54)],
    ]
    static let tailplane: [[CGPoint]] = [
        [CGPoint(x: 47, y: 78), CGPoint(x: 31, y: 88), CGPoint(x: 31, y: 92), CGPoint(x: 47, y: 88)],
        [CGPoint(x: 53, y: 78), CGPoint(x: 69, y: 88), CGPoint(x: 69, y: 92), CGPoint(x: 53, y: 88)],
    ]
    // Rounded bars: (centre x, top, bottom, width).
    static let engines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(28, 40, 56, 8), (72, 40, 56, 8)]
    static let fuselage: (CGFloat, CGFloat, CGFloat, CGFloat) = (50, 4, 94, 11)
    static let fin: (CGFloat, CGFloat, CGFloat, CGFloat) = (50, 76, 95, 3)
    static let cockpit: (CGFloat, CGFloat, CGFloat, CGFloat) = (50, 9, 14, 6)
}

/// Polygons or rounded bars on the jet's 100 × 100 grid, scaled to the frame.
private struct JetPart: Shape {
    var points: [[CGPoint]] = []
    var capsules: [(CGFloat, CGFloat, CGFloat, CGFloat)] = []

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 100
        let ox = rect.midX - 50 * s, oy = rect.midY - 50 * s
        func p(_ q: CGPoint) -> CGPoint { CGPoint(x: ox + q.x * s, y: oy + q.y * s) }
        var path = Path()
        for poly in points {
            path.move(to: p(poly[0]))
            for q in poly.dropFirst() { path.addLine(to: p(q)) }
            path.closeSubpath()
        }
        for (cx, top, bottom, w) in capsules {
            let r = CGRect(x: ox + (cx - w / 2) * s, y: oy + top * s, width: w * s, height: (bottom - top) * s)
            path.addRoundedRect(in: r, cornerSize: CGSize(width: w * s / 2, height: w * s / 2))
        }
        return path
    }
}
