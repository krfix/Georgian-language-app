import SwiftUI

// The Learn path's vine (owner, KART #15): the path keeps its stones, icons, titles and swing,
// runs from the bottom up, and the ribbon behind the stones is a grapevine. Below the lesson
// up next the vine is old brown wood, turning into a green shoot above it; lessons done hang
// purple grape bunches, the lesson up next a green bunch, the lessons ahead leaves, twigs and
// curling tendrils. The stem is drawn here; leaves, bunches and tendrils are pictures from
// tools/brand/make_brand.py --vine (Assets.xcassets/Vine).

/// A point on the stem: where it is, and its place in the course (lesson index, fractional
/// between lessons), which decides how thick and how woody the stem is there.
struct VinePoint {
    var x: CGFloat
    var y: CGFloat
    var u: Double
    var isNode = false
    /// Set where the vine must match something drawn in a picture (the supra table's old vine):
    /// its woodiness and width there, instead of the ones its place in the course gives.
    var wood: Double? = nil
    var width: CGFloat? = nil

    func woodiness(_ state: VineState) -> Double { wood ?? state.wood(u) }
    func thickness(_ state: VineState) -> CGFloat { width ?? state.width(u) }
}

/// Everything about the learner's vine that doesn't depend on where it is drawn.
struct VineState {
    /// Course index of the lesson up next (nil when every lesson is done).
    let next: Double?
    let lessonCount: Double

    /// 0 green shoot, about 0.45 yellow, 0.7 cane, 1 old bark: woody well below the next
    /// lesson, turning over the last few lessons done, green from the next lesson up.
    func wood(_ u: Double) -> Double {
        guard let next else { return 0.95 }
        let dn = (next - u) * 92
        return dn >= 0 ? min(1, 0.22 + dn / 300) : max(0, 0.22 + dn / 160)
    }

    func width(_ u: Double) -> CGFloat {
        let age = 1 - max(0, min(1, u / max(1, lessonCount)))
        let m = wood(u)
        return CGFloat((6 + 16 * pow(age, 1.3)) * (0.7 + 0.3 * smoothstep(0, 0.6, m)))
    }
}

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

// MARK: - Colours

/// The stem's colours (the same as VINE_COLOURS in tools/brand/vine.py), mixed as RGB.
struct VineInk {
    struct RGB {
        var r, g, b: Double
        init(_ hex: Int) { r = Double((hex >> 16) & 255) / 255; g = Double((hex >> 8) & 255) / 255; b = Double(hex & 255) / 255 }
        init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
        func mix(_ o: RGB, _ t: Double) -> RGB {
            let t = max(0, min(1, t))
            return RGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
        }
        var color: Color { Color(red: r, green: g, blue: b) }
    }

    let bark, barkDeep, barkLight, barkStrip, cane, straw, shoot, shootDeep, shootLight, node, wood, woodDeep, woodLight, rope: RGB

    static let light = VineInk(bark: RGB(0x6B4A30), barkDeep: RGB(0x46301E), barkLight: RGB(0x9C7650), barkStrip: RGB(0x553922),
                               cane: RGB(0xA0764B), straw: RGB(0xC9B15C), shoot: RGB(0x7DB65A), shootDeep: RGB(0x4E8A36),
                               shootLight: RGB(0xB5DB8E), node: RGB(0x5A3E28), wood: RGB(0x7B5638), woodDeep: RGB(0x5A3B24),
                               woodLight: RGB(0xA57A52), rope: RGB(0xC8A77A))
    static let dark = VineInk(bark: RGB(0x8C6748), barkDeep: RGB(0x5A3F2A), barkLight: RGB(0xB8926A), barkStrip: RGB(0x6E4E34),
                              cane: RGB(0xB48A5C), straw: RGB(0xB9A456), shoot: RGB(0x6FAE52), shootDeep: RGB(0x3F7A2E),
                              shootLight: RGB(0xA2D47F), node: RGB(0x6E4E34), wood: RGB(0x9C7350), woodDeep: RGB(0x6E4C31),
                              woodLight: RGB(0xC49A6E), rope: RGB(0xA8875C))

    static func of(_ scheme: ColorScheme) -> VineInk { scheme == .dark ? dark : light }

    func stem(_ m: Double) -> RGB {
        if m < 0.45 { return shoot.mix(straw, m / 0.45) }
        if m < 0.7 { return straw.mix(cane, (m - 0.45) / 0.25) }
        return cane.mix(bark, (m - 0.7) / 0.3)
    }

    func edge(_ m: Double) -> RGB { shootDeep.mix(barkDeep, smoothstep(0.2, 0.8, m)) }
}

/// A repeatable random number in 0..<1 for a place on the vine, so every row draws the same
/// blotch at the same spot.
private func noise(_ u: Double, _ salt: Int) -> Double {
    let x = sin(u * 12.9898 * 57 + Double(salt) * 78.233) * 43758.5453
    return x - floor(x)
}

// MARK: - Drawing the stem

enum VineStem {
    /// Points along the smooth curve (Catmull-Rom) through `pts`, about 4 points apart, each
    /// with its course position.
    static func sample(_ pts: [VinePoint], within band: ClosedRange<CGFloat>, state: VineState) -> [[VinePoint]] {
        // Pieces whose ends are both far outside the band are skipped; runs are kept apart so
        // a skipped piece never joins two others with a straight line.
        var runs: [[VinePoint]] = [], run: [VinePoint] = []
        let n = pts.count - 1
        guard n > 0 else { return [] }
        for i in 0..<n {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(n, i + 2)]
            let lo = min(p1.y, p2.y) - 60, hi = max(p1.y, p2.y) + 60
            guard hi >= band.lowerBound && lo <= band.upperBound else {
                if !run.isEmpty { runs.append(run); run = [] }
                continue
            }
            let per = max(4, Int(hypot(p2.x - p1.x, p2.y - p1.y) / 6))
            for j in 0..<per {
                let t = CGFloat(j) / CGFloat(per)
                let t2 = t * t, t3 = t2 * t
                func cr(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
                    let k1: CGFloat = c - a
                    let k2: CGFloat = 2 * a - 5 * b + 4 * c - d
                    let k3: CGFloat = 3 * (b - c) + d - a
                    let sum: CGFloat = 2 * b + k1 * t + k2 * t2 + k3 * t3
                    return sum / 2
                }
                var q = VinePoint(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y),
                                  u: p1.u + (p2.u - p1.u) * Double(t))
                // Overrides fade in and out along the piece.
                if p1.wood != nil || p2.wood != nil {
                    let a = p1.woodiness(state), b = p2.woodiness(state)
                    q.wood = a + (b - a) * Double(t)
                }
                if p1.width != nil || p2.width != nil {
                    let a = p1.thickness(state), b = p2.thickness(state)
                    q.width = a + (b - a) * t
                }
                run.append(q)
            }
            if i == n - 1 { run.append(p2) }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
    }

    static func draw(_ ctx: inout GraphicsContext, points: [VinePoint], band: ClosedRange<CGFloat>, state: VineState, ink: VineInk) {
        for s in sample(points, within: band, state: state) where s.count > 1 {
            let n = s.count
            var normals: [CGPoint] = []
            for i in 0..<n {
                let a = s[max(0, i - 1)], b = s[min(n - 1, i + 1)]
                let dx = b.x - a.x, dy = b.y - a.y, ln = max(0.001, hypot(dx, dy))
                normals.append(CGPoint(x: -dy / ln, y: dx / ln))
            }
            let ws = s.map { $0.thickness(state) }
            let ms = s.map { $0.woodiness(state) }
            func quad(_ i: Int, _ extra: CGFloat) -> Path {
                let a = s[i], b = s[i + 1], na = normals[i], nb = normals[i + 1]
                let wa = ws[i] / 2 + extra, wb = ws[i + 1] / 2 + extra
                var p = Path()
                p.move(to: CGPoint(x: a.x + na.x * wa, y: a.y + na.y * wa))
                p.addLine(to: CGPoint(x: b.x + nb.x * wb, y: b.y + nb.y * wb))
                p.addLine(to: CGPoint(x: b.x - nb.x * wb, y: b.y - nb.y * wb))
                p.addLine(to: CGPoint(x: a.x - na.x * wa, y: a.y - na.y * wa))
                p.closeSubpath()
                return p
            }
            // The cartoon outline, then the stem itself, piece by piece.
            for i in 0..<(n - 1) {
                let c = ink.edge(ms[i]).color
                let q = quad(i, 1.4)
                ctx.fill(q, with: .color(c)); ctx.stroke(q, with: .color(c), lineWidth: 0.8)
            }
            for i in 0..<(n - 1) {
                let c = ink.stem(ms[i]).color
                let q = quad(i, 0)
                ctx.fill(q, with: .color(c)); ctx.stroke(q, with: .color(c), lineWidth: 0.7)
            }
            // The bark forming: brown streaks where the stem is turning woody.
            for i in stride(from: 2, to: n - 2, by: 3) {
                let m = ms[i], u = s[i].u
                guard m > 0.3 && m < 0.85 && noise(u, 1) < 0.55 else { continue }
                let k = CGFloat(noise(u, 2) * 0.36 - 0.18)
                let centre = CGPoint(x: s[i].x + normals[i].x * ws[i] * k, y: s[i].y + normals[i].y * ws[i] * k)
                let ang = atan2(s[i + 1].y - s[i - 1].y, s[i + 1].x - s[i - 1].x)
                let rx = CGFloat(6 + noise(u, 3) * 6) * CGFloat(0.5 + m), ry = ws[i] * CGFloat(0.1 + noise(u, 4) * 0.08)
                var e = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                e = e.applying(CGAffineTransform(rotationAngle: ang).concatenating(CGAffineTransform(translationX: centre.x, y: centre.y)))
                ctx.fill(e, with: .color((m < 0.6 ? ink.cane : ink.bark).color.opacity(0.3 + 0.4 * m)))
            }
            // Shaggy, torn strips on the old bark.
            for (li, lane) in [-0.28, -0.06, 0.16, 0.33].enumerated() {
                for i in 0..<(n - 1) where ms[i] >= 0.75 {
                    if noise(s[i].u, 10 + li) < 0.08 { continue }
                    let wob = { (j: Int) -> CGFloat in CGFloat(lane + 0.05 * sin(s[j].u * 9 + Double(li) * 2)) }
                    let a = CGPoint(x: s[i].x + normals[i].x * ws[i] * wob(i), y: s[i].y + normals[i].y * ws[i] * wob(i))
                    let b = CGPoint(x: s[i + 1].x + normals[i + 1].x * ws[i + 1] * wob(i + 1), y: s[i + 1].y + normals[i + 1].y * ws[i + 1] * wob(i + 1))
                    var p = Path(); p.move(to: a); p.addLine(to: b)
                    let col = (lane < 0.1 ? ink.barkStrip : ink.barkLight).color.opacity(smoothstep(0.75, 0.95, ms[i]) * 0.8)
                    ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: lane < 0.1 ? 1.3 : 1.0, lineCap: .butt))
                }
            }
            // A light streak down the young stem, for roundness.
            var streak = Path(), started = false, wsum: CGFloat = 0, count: CGFloat = 0
            for i in 0..<n {
                guard ms[i] < 0.6 else { started = false; continue }
                let p = CGPoint(x: s[i].x - normals[i].x * ws[i] * 0.22, y: s[i].y - normals[i].y * ws[i] * 0.22)
                if started { streak.addLine(to: p) } else { streak.move(to: p); started = true }
                wsum += ws[i]; count += 1
            }
            if count > 1 {
                ctx.stroke(streak, with: .color(ink.shootLight.color.opacity(0.5)),
                           style: StrokeStyle(lineWidth: wsum / count * 0.15, lineCap: .round, lineJoin: .round))
            }
        }
        // Nodes: the slight swellings where leaves grow.
        for (i, p) in points.enumerated() where p.isNode && band.contains(p.y) {
            let a = points[max(0, i - 1)], b = points[min(points.count - 1, i + 1)]
            let ang = atan2(b.y - a.y, b.x - a.x) + .pi / 2
            let m = p.woodiness(state), w = p.thickness(state)
            let rx = w * 0.56 + 0.8, ry = max(2.2, w * 0.22)
            var e = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            e = e.applying(CGAffineTransform(rotationAngle: ang).concatenating(CGAffineTransform(translationX: p.x, y: p.y)))
            ctx.fill(e, with: .color(ink.stem(m).color))
            ctx.stroke(e, with: .color(ink.edge(m).mix(ink.stem(m), 0.35).color.opacity(0.6)), lineWidth: 1)
        }
    }
}

// MARK: - Leaves, tendrils and stalks around the stem

enum VineGrowth {
    /// A stalk from the node to a leaf or bunch, bowing a little.
    static func stalk(_ ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint, wood m: Double, ink: VineInk, bend: CGFloat = 0.3, width: CGFloat = 2.6) {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * bend, y: (a.y + b.y) / 2 - (b.x - a.x) * bend))
        ctx.stroke(p, with: .color(ink.shootDeep.mix(ink.cane, m).color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    /// A picture drawn with its centre at `at`, `size` points across, turned by `degrees`.
    static func picture(_ ctx: inout GraphicsContext, _ name: String, at: CGPoint, size: CGFloat, degrees: Double = 0) {
        var c = ctx
        c.translateBy(x: at.x, y: at.y)
        c.rotate(by: .degrees(degrees))
        c.draw(Image(name), in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
    }

    /// A leaf on its stalk: the stalk runs from the stem at `from` out to `side` (+1 right, -1
    /// left), and the leaf hangs from the stalk's end, its blade turned away from the stem by
    /// `angle` degrees. The leaf is placed so that its notch (where a grape leaf's stalk joins
    /// it) sits exactly on the stalk's end, however far it is turned.
    static func leaf(_ ctx: inout GraphicsContext, _ name: String, from: CGPoint, side: CGFloat, reach: CGFloat, size: CGFloat,
                     angle: Double, wood m: Double, ink: VineInk) {
        let end = CGPoint(x: from.x + side * reach, y: from.y - reach * 0.25)
        stalk(&ctx, from: from, to: end, wood: m, ink: ink, bend: side * 0.3, width: 2.2)
        let centre = leafCentre(name, from: from, side: side, reach: reach, size: size, angle: angle)
        picture(&ctx, name, at: centre, size: size, degrees: -Double(side) * angle)
    }

    /// Where `leaf` puts the leaf's centre. In the pictures the leaf (44 points across on a
    /// 60-point canvas, or 28 on 40 for a young one) has its notch 0.155 of the leaf's width
    /// above the canvas centre.
    static func leafCentre(_ name: String, from: CGPoint, side: CGFloat, reach: CGFloat, size: CGFloat, angle: Double) -> CGPoint {
        let end = CGPoint(x: from.x + side * reach, y: from.y - reach * 0.25)
        let leafWidth = size * (name.hasPrefix("VineLeafYoung") ? 28.0 / 40 : 44.0 / 60)
        let r = leafWidth * 0.155
        let t = -Double(side) * angle * .pi / 180
        return CGPoint(x: end.x - r * CGFloat(sin(t)), y: end.y + r * CGFloat(cos(t)))
    }

    /// A tendril (canvas 80, starting at (8, 40) heading right, 56 long) from `at`, `length`
    /// long, heading at `degrees`.
    static func tendril(_ ctx: inout GraphicsContext, _ index: Int, at: CGPoint, length: CGFloat, degrees: Double) {
        let s = length / 56
        var c = ctx
        c.translateBy(x: at.x, y: at.y)
        c.rotate(by: .degrees(degrees))
        c.scaleBy(x: s, y: s)
        c.draw(Image("VineTendril\(index)"), in: CGRect(x: -8, y: -40, width: 80, height: 80))
    }
}

// MARK: - The vine behind the path

/// One stone on the path, for the vine: where it is, its place in the course and its state.
struct VineStop {
    let point: CGPoint
    let index: Int
    let state: LessonState
    /// The first lesson of its module (the module's card hangs below it).
    let firstInModule: Bool
}

/// Where the vine runs and what grows where, worked out once for every layer: the vine behind
/// the path, its last stretch climbing in front of the supra table, and Ara's perch.
struct VineLayout {
    struct Gap {
        let stop: VineStop
        let at: CGPoint
        let side: CGFloat
    }

    /// Ara beside the lesson up next: where its feet are, the stem point its twig grows from,
    /// and which way it faces (+1 right).
    struct Perch {
        let feet: CGPoint
        let from: CGPoint
        let facing: CGFloat
        /// Ara's picture: 0.686 as wide as it is tall, feet at (0.464, 0.690) of it
        /// (make_brand.py's mascot canvas).
        static let height: CGFloat = 64
        static let aspect: CGFloat = 0.686
        static let feetAt = CGPoint(x: 0.464, y: 0.690)
        var frame: CGRect {
            let w = Self.height * Self.aspect
            let fx = facing > 0 ? Self.feetAt.x : 1 - Self.feetAt.x
            return CGRect(x: feet.x - fx * w, y: feet.y - Self.feetAt.y * Self.height, width: w, height: Self.height)
        }
    }

    var points: [VinePoint] = []
    var gaps: [Gap] = []
    /// The climb from the last lesson to the old vine on the pergola's beam.
    var climb: [VinePoint] = []
    var top: CGRect?
    /// Where nothing may grow: the titles and the stones (and Ara).
    var obstacles: [CGRect] = []
    var perch: Perch?
    /// The last lesson's stone: the climb in front of the picture stops above it.
    var lastStone: CGPoint?

    init(stops: [VineStop], top: CGRect?, finished: Bool, texts: [CGRect], width: CGFloat) {
        self.top = top
        obstacles = texts.map { $0.insetBy(dx: -6, dy: -4) }
            + stops.map { CGRect(x: $0.point.x - 40, y: $0.point.y - 40, width: 80, height: 80) }
        guard let first = stops.first else { return }
        lastStone = stops.last?.point
        func clear(_ p: CGPoint) -> Bool { !texts.contains { $0.insetBy(dx: -14, dy: -8).contains(p) } }
        points.append(VinePoint(x: first.point.x, y: first.point.y + 240, u: -1))
        for (i, s) in stops.enumerated() {
            // The stem bows out to one side between stones, as the ribbon did, but never into a
            // title (with large text they reach down into the gaps).
            var bow: CGFloat = s.index % 2 == 0 ? 30 : -30
            if i > 0 && !s.firstInModule {
                let b = stops[i - 1].point
                var mid = CGPoint(x: (s.point.x + b.x) / 2 + bow, y: (s.point.y + b.y) / 2)
                if !clear(mid) {
                    bow = -bow
                    mid.x = (s.point.x + b.x) / 2 + bow
                }
                points.append(VinePoint(x: mid.x, y: mid.y, u: Double(s.index) - 0.5, isNode: true))
                gaps.append(Gap(stop: s, at: mid, side: bow > 0 ? 1 : -1))
            } else {
                // A module's first lesson: the card hangs below it. The vine keeps swinging:
                // out to one side above the card, behind it, and out to the other side below it
                // before the stone underneath (it used to drop straight down).
                var above = CGPoint(x: s.point.x + bow, y: s.point.y + 72)
                if !clear(above) {
                    bow = -bow
                    above.x = s.point.x + bow
                }
                if i > 0 {
                    let b = stops[i - 1].point
                    let below = CGPoint(x: b.x - bow * 0.9, y: b.y - 64)
                    points.append(VinePoint(x: below.x, y: below.y, u: Double(s.index) - 0.9, isNode: true))
                    let span = below.y - above.y
                    points.append(VinePoint(x: (b.x + s.point.x) / 2 + bow * 1.2, y: below.y - span * 0.35, u: Double(s.index) - 0.75))
                    points.append(VinePoint(x: (b.x + s.point.x) / 2 - bow * 1.2, y: below.y - span * 0.7, u: Double(s.index) - 0.6))
                }
                points.append(VinePoint(x: above.x, y: above.y, u: Double(s.index) - 0.4, isNode: true))
                gaps.append(Gap(stop: s, at: above, side: bow > 0 ? 1 : -1))
            }
            points.append(VinePoint(x: s.point.x, y: s.point.y, u: Double(s.index)))
        }
        if let top, let last = stops.last {
            climb = Self.climb(from: last.point, to: top, u: Double(last.index), finished: finished)
            points += climb
        }
        perch = Self.perch(stops: stops, gaps: gaps, obstacles: obstacles, width: width)
        if let perch { obstacles.append(perch.frame.insetBy(dx: -4, dy: -4)) }
    }

    /// Ara's perch: on a twig in the gap just above the lesson up next (or just below it),
    /// on whichever side there is room, facing the stem.
    static func perch(stops: [VineStop], gaps: [Gap], obstacles: [CGRect], width: CGFloat) -> Perch? {
        guard let ci = stops.firstIndex(where: { $0.state == .current }) else { return nil }
        var spots: [CGPoint] = []
        if ci + 1 < stops.count, let g = gaps.first(where: { $0.stop.index == stops[ci + 1].index }), !stops[ci + 1].firstInModule {
            spots.append(g.at)
        }
        // Beside the stone itself, on its free side (the title is on its right).
        let c = stops[ci].point
        spots.append(CGPoint(x: c.x - 8, y: c.y + 26))
        // Below it, where its green bunch hangs (the bunch then takes the other side).
        if let g = gaps.first(where: { $0.stop.index == stops[ci].index }) { spots.append(g.at) }
        for spot in spots {
            for side: CGFloat in [-1, 1] {
                for reach: CGFloat in [36, 46, 56] {
                    let feet = CGPoint(x: spot.x + side * reach, y: spot.y + 6)
                    let p = Perch(feet: feet, from: spot, facing: -side)
                    let f = p.frame
                    guard f.minX >= 4, f.maxX <= width - 4 else { continue }
                    if !obstacles.contains(where: { $0.intersects(f.insetBy(dx: 4, dy: 6)) }) { return p }
                }
            }
        }
        return nil
    }

    /// The climb: a young shoot (until the course is done) from the last lesson, in front of
    /// the table, past the jug, up to the stub of the old vine wound round the beam, where it
    /// takes on the old vine's colour and width to meet it. Positions are in the picture's own
    /// units (402 by 340), scaled to its frame, so it fits every screen width.
    static func climb(from last: CGPoint, to art: CGRect, u: Double, finished: Bool) -> [VinePoint] {
        let s = art.width / 402
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: art.minX + x * s, y: art.minY + y * s) }
        let p1 = CGPoint(x: (last.x + at(80, 0).x) / 2 + 20, y: min(last.y - 96, art.maxY + 40))
        let p2 = at(88, 336), p3 = at(70, 270), p4 = at(46, 205), p5 = at(26, 150), p6 = at(20, 110)
        // The old vine is green until the course is done, brown wood after.
        let old: Double = finished ? 1 : 0.02
        return [
            VinePoint(x: p1.x, y: p1.y, u: u + 0.5, isNode: true),
            VinePoint(x: p2.x, y: p2.y, u: u + 1.1, isNode: true),
            VinePoint(x: p3.x, y: p3.y, u: u + 1.6, isNode: true),
            VinePoint(x: p4.x, y: p4.y, u: u + 2.1, isNode: true),
            VinePoint(x: p5.x, y: p5.y, u: u + 2.5, isNode: true, wood: finished ? 0.6 : 0.02, width: 5 * s),
            // The old vine's stub in the picture: 6 units wide.
            VinePoint(x: p6.x, y: p6.y, u: u + 2.8, wood: old, width: 6 * s),
            VinePoint(x: p6.x - 1 * s, y: p6.y - 30 * s, u: u + 3, wood: old, width: 6 * s),
        ]
    }
}

/// The vine through every stone, bottom to top, with the grapes, leaves and tendrils in the gap
/// below each stone, and Ara's twig. Its last stretch, the climb to the supra table, is drawn
/// again in front of the table by VineClimb.
struct VineRibbon: View {
    let layout: VineLayout
    let vine: VineState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = VineInk.of(scheme)
        let layout = self.layout
        let vine = self.vine
        Canvas { ctx, size in
            let grow = VineGrower(vine: vine, ink: ink, width: size.width, obstacles: layout.obstacles)
            // Leaves and tendrils go under the stem, so it covers where they join; the bunches
            // hang over it.
            for g in layout.gaps { grow.gap(&ctx, g, bunches: false) }
            VineStem.draw(&ctx, points: layout.points, band: -400...(size.height + 400), state: vine, ink: ink)
            if let p = layout.perch {
                // Ara's twig: from the stem out under its feet, and a little beyond.
                let tip = CGPoint(x: p.feet.x - p.facing * 14, y: p.feet.y + 1)
                VineGrowth.stalk(&ctx, from: p.from, to: tip, wood: min(1, vine.wood(Double(vine.next ?? 0)) + 0.3), ink: ink,
                                 bend: 0.12 * -p.facing, width: 4.5)
            }
            for g in layout.gaps { grow.gap(&ctx, g, bunches: true) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The climb to the supra table, drawn over the picture so the young vine passes in front of
/// the table and joins the old vine on the beam; it stops above the last lesson's stone.
struct VineClimb: View {
    let layout: VineLayout
    let vine: VineState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = VineInk.of(scheme)
        let layout = self.layout
        let vine = self.vine
        Canvas { ctx, size in
            guard let top = layout.top, !layout.climb.isEmpty else { return }
            let bottom = min(top.maxY + 150, (layout.lastStone?.y ?? .greatestFiniteMagnitude) - 46)
            ctx.clip(to: Path(CGRect(x: 0, y: top.minY, width: size.width, height: max(0, bottom - top.minY))))
            let grow = VineGrower(vine: vine, ink: ink, width: size.width, obstacles: layout.obstacles)
            grow.climb(&ctx, layout.climb, bunches: false)
            VineStem.draw(&ctx, points: layout.points, band: top.minY...bottom, state: vine, ink: ink)
            grow.climb(&ctx, layout.climb, bunches: true)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Ara the parrot perched on its twig beside the lesson up next, facing the stem.
struct VinePerchView: View {
    let perch: VineLayout.Perch?

    var body: some View {
        if let perch {
            let f = perch.frame
            ParrotView(height: VineLayout.Perch.height, mood: .hello, bobbing: false)
                .scaleEffect(x: perch.facing > 0 ? 1 : -1, y: 1)
                .frame(width: f.width, height: f.height)
                .position(x: f.midX, y: f.midY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// What grows on the vine, mixed up as it climbs: every gap draws its own choice of leaf
/// shapes, sizes, angles, sides and tendrils from a repeatable random number. Nothing may pass
/// the screen's edges or touch a title, a stone or Ara: each piece tries the other side, a
/// smaller size or another angle, and is left out if none fits.
struct VineGrower {
    let vine: VineState
    let ink: VineInk
    let width: CGFloat
    let obstacles: [CGRect]
    let margin: CGFloat = 6

    private func rnd(_ u: Double, _ salt: Int) -> Double { noise(u + 0.37, salt) }

    private func free(_ r: CGRect) -> Bool {
        r.minX >= margin && r.maxX <= width - margin && !obstacles.contains { $0.intersects(r) }
    }

    /// A leaf from `g`, trying its side, then the other, smaller and turned further out.
    private func leaf(_ ctx: inout GraphicsContext, _ name: String, from g: CGPoint, side: CGFloat, reach: CGFloat,
                      size: CGFloat, angle: Double, wood m: Double) {
        for s in [side, -side] {
            for k: CGFloat in [1, 0.82, 0.66] {
                for a in [angle, min(85, angle + 25)] {
                    let c = VineGrowth.leafCentre(name, from: g, side: s, reach: reach, size: size * k, angle: a)
                    let half = size * k * 0.34
                    if free(CGRect(x: c.x - half, y: c.y - half, width: half * 2, height: half * 2)) {
                        VineGrowth.leaf(&ctx, name, from: g, side: s, reach: reach, size: size * k, angle: a, wood: m * 0.6, ink: ink)
                        return
                    }
                }
            }
        }
    }

    private func tendril(_ ctx: inout GraphicsContext, _ index: Int, at g: CGPoint, side: CGFloat, length: CGFloat, rise: Double) {
        for s in [side, -side] {
            for k: CGFloat in [1, 0.75] {
                let deg = s > 0 ? -rise : 180 + rise
                let t = deg * .pi / 180
                let end = CGPoint(x: g.x + length * k * 0.8 * CGFloat(cos(t)), y: g.y + length * k * 0.8 * CGFloat(sin(t)))
                let pad = length * k * 0.22
                let r = CGRect(x: min(g.x, end.x) - pad, y: min(g.y, end.y) - pad,
                               width: abs(end.x - g.x) + pad * 2, height: abs(end.y - g.y) + pad * 2)
                // The tendril's own start touches the stem, so only its far part is checked.
                if free(r.insetBy(dx: r.width * 0.15, dy: 0)) {
                    VineGrowth.tendril(&ctx, index, at: g, length: length * k, degrees: deg)
                    return
                }
            }
        }
    }

    private func leafName(_ u: Double, _ salt: Int, young: Bool) -> String {
        young ? "VineLeafYoung\(Int(rnd(u, salt) * 3) + 1)" : "VineLeaf\(Int(rnd(u, salt) * 10) + 1)"
    }

    /// A bunch hanging from `g`: on its side if there is room, else the other, else smaller.
    private func bunch(_ ctx: inout GraphicsContext, _ name: String, from g: CGPoint, side: CGFloat, size: CGFloat, tilt: Double, wood m: Double) {
        var choice: (CGFloat, CGFloat)?
        search: for k: CGFloat in [1, 0.85, 0.72] {
            for s in [side, -side] {
                let c = CGPoint(x: g.x + s * (30 + size * k * 0.14), y: g.y + 8)
                let r = CGRect(x: c.x - size * k * 0.3, y: c.y - size * k * 0.28, width: size * k * 0.6, height: size * k * 0.66)
                if free(r) { choice = (s, k); break search }
            }
        }
        // Nowhere free: the smallest size, on the side that covers least.
        let (s, k) = choice ?? {
            func overlap(_ s: CGFloat) -> CGFloat {
                let c = CGPoint(x: g.x + s * (30 + size * 0.1), y: g.y + 8)
                let r = CGRect(x: c.x - size * 0.22, y: c.y - size * 0.2, width: size * 0.44, height: size * 0.48)
                var area: CGFloat = 0
                for o in obstacles {
                    let i = o.intersection(r)
                    if !i.isNull { area += i.width * i.height }
                }
                return area
            }
            return (overlap(side) <= overlap(-side) ? side : -side, 0.72)
        }()
        let sz = size * k
        let c = CGPoint(x: g.x + s * (30 + sz * 0.14), y: g.y + 8)
        VineGrowth.stalk(&ctx, from: g, to: CGPoint(x: c.x, y: c.y - sz * 0.35), wood: m, ink: ink, bend: s * -0.25, width: 2.6)
        var flip = ctx
        if s < 0 {
            flip.translateBy(x: c.x, y: 0); flip.scaleBy(x: -1, y: 1); flip.translateBy(x: -c.x, y: 0)
        }
        VineGrowth.picture(&flip, name, at: c, size: sz, degrees: Double(s) * tilt)
    }

    /// What grows in the gap below a stone: a bunch (purple when done, green for the lesson up
    /// next) with leaves round it, or for lessons ahead leaves, twigs and curling tendrils.
    func gap(_ ctx: inout GraphicsContext, _ gap: VineLayout.Gap, bunches: Bool) {
        let s = gap.stop, g = gap.at
        let u = Double(s.index)
        let m = vine.wood(u - 0.5)
        let fruit = s.state == .completed || s.state == .current
        if bunches {
            guard fruit else { return }
            let colour = s.state == .completed ? "Purple" : "Green"
            bunch(&ctx, "VineBunch\(colour)\(Int(rnd(u, 3) * 3) + 1)", from: g, side: gap.side, size: CGFloat(74 + rnd(u, 1) * 12),
                  tilt: rnd(u, 4) * 10 - 2, wood: m)
            return
        }
        let young = vine.next.map { u > $0 + 3.5 && rnd(u, 5) < 0.6 } ?? false
        let away: CGFloat = fruit ? -gap.side : gap.side
        // One to three leaves, each its own shape, size and angle; the first on the side away
        // from the bunch, the others wherever the dice say.
        let count = fruit ? 1 + Int(rnd(u, 6) * 2) : 2 + Int(rnd(u, 6) * 2)
        for i in 0..<count {
            let side = i == 0 ? away : (rnd(u, 10 + i) < 0.5 ? 1 : -1)
            let from = CGPoint(x: g.x, y: g.y + CGFloat(i) * CGFloat(rnd(u, 20 + i) * 16 - 8))
            let size = CGFloat(i == 0 ? 46 + rnd(u, 30) * 20 : 34 + rnd(u, 30 + i) * 16) * (young ? 0.85 : 1)
            leaf(&ctx, leafName(u, 40 + i, young: young && i > 0), from: from, side: side, reach: CGFloat(14 + rnd(u, 50 + i) * 12),
                 size: size, angle: 20 + rnd(u, 60 + i) * 55, wood: m)
        }
        // Tendrils: almost always ahead, now and then by the fruit; sometimes two, curling out
        // to different sides.
        let tendrils = fruit ? (rnd(u, 70) < 0.4 ? 1 : 0) : (rnd(u, 70) < 0.35 ? 2 : 1)
        for i in 0..<tendrils {
            let side: CGFloat = i == 0 ? -away : away
            tendril(&ctx, Int(rnd(u, 80 + i) * 6) + 1, at: CGPoint(x: g.x, y: g.y - 3 - CGFloat(i) * 6), side: side,
                    length: CGFloat(38 + rnd(u, 90 + i) * 26), rise: 10 + rnd(u, 100 + i) * 50)
        }
    }

    /// What grows on the climb to the supra table: leaves of every kind, tendrils, and two
    /// bunches, green until the course is done.
    func climb(_ ctx: inout GraphicsContext, _ points: [VinePoint], bunches: Bool) {
        for (i, p) in points.prefix(5).enumerated() {
            let g = CGPoint(x: p.x, y: p.y)
            let u = p.u + 100
            let m = p.woodiness(vine)
            if bunches {
                guard i == 1 || i == 3 else { continue }
                bunch(&ctx, "VineBunch\(vine.next == nil ? "Purple" : "Green")\(i % 3 + 1)", from: g, side: 1, size: 76, tilt: 3, wood: m)
                continue
            }
            for j in 0..<(2 + Int(rnd(u, 1) * 2)) {
                let side: CGFloat = j == 0 ? -1 : (rnd(u, 10 + j) < 0.6 ? 1 : -1)
                leaf(&ctx, leafName(u, 20 + j, young: false), from: CGPoint(x: g.x, y: g.y - CGFloat(j) * 9), side: side,
                     reach: CGFloat(12 + rnd(u, 30 + j) * 12), size: CGFloat(40 + rnd(u, 40 + j) * 22),
                     angle: 25 + rnd(u, 50 + j) * 55, wood: m)
            }
            tendril(&ctx, Int(rnd(u, 60) * 6) + 1, at: CGPoint(x: g.x, y: g.y - 5), side: i % 2 == 0 ? 1 : -1,
                    length: CGFloat(40 + rnd(u, 61) * 20), rise: 20 + rnd(u, 62) * 40)
        }
    }
}

// MARK: - The top of the vine: the supra table

struct VineTop: View {
    let finished: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(tr("Tamada"))
                .font(.titleBold)
                .foregroundStyle(finished ? Palette.ink : Palette.inkSoft)
            Text(finished ? tr("Every lesson done: the table is yours.") : tr("At the top of the vine: a seat at the supra table."))
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            // The grown vine over the table, the goal; the climbing shoot joins it at the beam
            // (VineRibbon.climb uses the picture's proportions, 402 by 340).
            Image(finished ? "VineTopRipe" : "VineTop")
                .resizable()
                .aspectRatio(402.0 / 340.0, contentMode: .fit)
                .accessibilityHidden(true)
                // The picture's own corners, for where the climbing vine meets its old vine
                // (measured on the picture itself: the block around it is narrower).
                .transformAnchorPreference(key: StoneCentres.self, value: .topLeading) { $0["vine-top-a"] = $1 }
                .transformAnchorPreference(key: StoneCentres.self, value: .bottomTrailing) { $0["vine-top-b"] = $1 }
        }
        .padding(.top, 8)
        .padding(.bottom, 70)
        .accessibilityElement(children: .combine)
    }
}
