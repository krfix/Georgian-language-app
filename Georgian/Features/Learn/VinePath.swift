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
    static func sample(_ pts: [VinePoint], within band: ClosedRange<CGFloat>) -> [[VinePoint]] {
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
                run.append(VinePoint(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y),
                                     u: p1.u + (p2.u - p1.u) * Double(t)))
            }
            if i == n - 1 { run.append(p2) }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
    }

    static func draw(_ ctx: inout GraphicsContext, points: [VinePoint], band: ClosedRange<CGFloat>, state: VineState, ink: VineInk) {
        for s in sample(points, within: band) where s.count > 1 {
            let n = s.count
            var normals: [CGPoint] = []
            for i in 0..<n {
                let a = s[max(0, i - 1)], b = s[min(n - 1, i + 1)]
                let dx = b.x - a.x, dy = b.y - a.y, ln = max(0.001, hypot(dx, dy))
                normals.append(CGPoint(x: -dy / ln, y: dx / ln))
            }
            let ws = s.map { state.width($0.u) }
            let ms = s.map { state.wood($0.u) }
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
            let m = state.wood(p.u), w = state.width(p.u)
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

/// The vine through every stone, bottom to top, and on up into the supra table; with the
/// grapes, leaves and tendrils in the gap below each stone.
struct VineRibbon: View {
    let stops: [VineStop]
    /// The supra table picture's frame, where the vine ends.
    let top: CGRect?
    let vine: VineState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = VineInk.of(scheme)
        let stops = self.stops
        let top = self.top
        Canvas { ctx, size in
            guard let first = stops.first else { return }
            var points: [VinePoint] = [VinePoint(x: first.point.x, y: first.point.y + 220, u: -1)]
            var gaps: [(stop: VineStop, at: CGPoint, side: CGFloat)] = []
            for (i, s) in stops.enumerated() {
                points.append(VinePoint(x: s.point.x, y: s.point.y, u: Double(s.index)))
                // The gap below this stone: halfway to the stone below, the stem bowing out to
                // one side as the ribbon did; for a module's first lesson, above its card.
                let bow: CGFloat = s.index % 2 == 0 ? 30 : -30
                if i > 0 && !s.firstInModule {
                    let b = stops[i - 1].point
                    let mid = CGPoint(x: (s.point.x + b.x) / 2 + bow, y: (s.point.y + b.y) / 2)
                    points.insert(VinePoint(x: mid.x, y: mid.y, u: Double(s.index) - 0.5, isNode: true), at: points.count - 1)
                    gaps.append((stop: s, at: mid, side: bow > 0 ? CGFloat(1) : CGFloat(-1)))
                } else {
                    gaps.append((stop: s, at: CGPoint(x: s.point.x + bow * 0.6, y: s.point.y + 78), side: bow > 0 ? CGFloat(1) : CGFloat(-1)))
                    if i > 0 {
                        // Under the card: on down to the stone below.
                        let b = stops[i - 1].point
                        points.insert(VinePoint(x: (s.point.x + b.x) / 2, y: (s.point.y + b.y) / 2, u: Double(s.index) - 0.5),
                                      at: points.count - 1)
                    }
                }
            }
            if let top, let last = stops.last {
                let u = Double(last.index)
                // Up the left edge, past the words and the table, into the leaves overhead.
                points.append(VinePoint(x: top.minX + top.width * 0.08, y: top.maxY - 10, u: u + 0.8, isNode: true))
                points.append(VinePoint(x: top.minX + top.width * 0.06, y: top.maxY - 150, u: u + 1.6))
                points.append(VinePoint(x: top.minX + top.width * 0.075, y: top.minY + top.width * 0.2, u: u + 2.4))
            }
            // Leaves and tendrils go under the stem, so it covers where they join; the bunches
            // hang over it.
            for g in gaps { growth(&ctx, g.stop, at: g.at, side: g.side, width: size.width, ink: ink, bunches: false) }
            VineStem.draw(&ctx, points: points, band: -400...(size.height + 400), state: self.vine, ink: ink)
            for g in gaps { growth(&ctx, g.stop, at: g.at, side: g.side, width: size.width, ink: ink, bunches: true) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// What grows in the gap below a stone: a bunch (purple when done, green for the lesson up
    /// next) with a leaf opposite it, or for lessons ahead leaves and curling tendrils.
    private func growth(_ ctx: inout GraphicsContext, _ s: VineStop, at g: CGPoint, side: CGFloat, width: CGFloat,
                        ink: VineInk, bunches: Bool) {
        let k = s.index
        let m = vine.wood(Double(k) - 0.5)
        // Keep things on screen: if the outer side has no room, use the other one.
        var side = side
        if g.x + side * 70 > width - 10 || g.x + side * 70 < 10 { side = -side }
        let fruit = s.state == .completed || s.state == .current
        if bunches {
            guard fruit else { return }
            let colour = s.state == .completed ? "Purple" : "Green"
            let c = CGPoint(x: g.x + side * 40, y: g.y + 8)
            VineGrowth.stalk(&ctx, from: g, to: CGPoint(x: c.x, y: c.y - 28), wood: m, ink: ink, bend: side * -0.25, width: 2.6)
            var flip = ctx
            if side < 0 {
                flip.translateBy(x: c.x, y: 0); flip.scaleBy(x: -1, y: 1); flip.translateBy(x: -c.x, y: 0)
            }
            VineGrowth.picture(&flip, "VineBunch\(colour)\(k % 3 + 1)", at: c, size: 80, degrees: Double(side) * 4)
            return
        }
        // A leaf on the side away from the bunch (or the outer side, ahead).
        let leafSide = fruit ? -side : side
        let young = vine.next.map { Double(k) > $0 + 1.5 } ?? false
        let leaf = CGPoint(x: g.x + leafSide * (fruit ? 30 : 38), y: g.y + 4)
        VineGrowth.stalk(&ctx, from: g, to: CGPoint(x: leaf.x - leafSide * 4, y: leaf.y - 14), wood: m * 0.6, ink: ink,
                         bend: leafSide * 0.3, width: 2.2)
        if young {
            VineGrowth.picture(&ctx, "VineLeafYoung\(k % 3 + 1)", at: leaf, size: CGFloat(30 + (k % 3) * 5) * 40 / 28,
                               degrees: Double(leafSide) * Double(30 + (k % 3) * 12))
        } else {
            VineGrowth.picture(&ctx, "VineLeaf\(k % 6 + 1)", at: leaf, size: CGFloat(fruit ? 34 : 40 + (k % 3) * 4) * 60 / 44,
                               degrees: Double(leafSide) * Double(30 + (k % 3) * 12))
        }
        // Ahead: tendrils curling out the other way, and a second, smaller leaf now and then.
        if !fruit {
            VineGrowth.tendril(&ctx, k % 4 + 1, at: CGPoint(x: g.x - leafSide * 2, y: g.y - 2), length: CGFloat(46 + (k % 3) * 8),
                               degrees: leafSide > 0 ? Double(160 + (k % 3) * 20) : Double(-20 + (k % 3) * 20))
            if k % 2 == 0 {
                let small = CGPoint(x: g.x - leafSide * 26, y: g.y + 20)
                VineGrowth.picture(&ctx, young ? "VineLeafYoung\((k + 1) % 3 + 1)" : "VineLeaf\((k + 3) % 6 + 1)", at: small,
                                   size: 34, degrees: Double(-leafSide) * 40)
            }
        } else if k % 3 == 0 {
            VineGrowth.tendril(&ctx, (k % 3) + 1, at: CGPoint(x: g.x, y: g.y + 2), length: 40,
                               degrees: side > 0 ? 200 : -20)
        }
    }
}

// MARK: - The top of the vine: the supra table

struct VineTop: View {
    let finished: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image("VineTop")
                .resizable()
                .scaledToFit()
                .opacity(finished ? 1 : 0.55)
                .accessibilityHidden(true)
            Text(tr("Tamada"))
                .font(.titleBold)
                .foregroundStyle(finished ? Palette.ink : Palette.inkFaint)
            Text(finished ? tr("Every lesson done: the table is yours.") : tr("At the top of the vine: a seat at the supra table."))
                .font(.calloutRounded)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}
