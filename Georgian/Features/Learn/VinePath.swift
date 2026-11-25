import SwiftUI

// The Learn path as a grapevine (docs/vine-path.md, KART #15). The vine grows from the bottom
// up: the first module at the bottom, each module a level whose card hangs from a trellis bar,
// its lessons above it. The stem is drawn here, live, so it can taper and turn from green
// shoot to brown bark where the learner has got to; the leaves, grape bunches, buds,
// tendrils, Ara on his branch and the supra table at the top are pictures made by
// tools/brand/make_brand.py --vine (Assets.xcassets/Vine). The canvas sizes and anchor points
// below must match vine_screens.app_assets().
//
// Each row draws its own piece of the stem (clipped to the row) from the same list of points,
// so the rows can be lazy and the stem still runs on unbroken from one row to the next.

enum VineMetrics {
    /// The stem's middle and how far it sways either side.
    static let stemMid: CGFloat = 92
    static let sway: CGFloat = 18
    /// From the stem to a lesson's picture, and where the titles start.
    static let itemDX: CGFloat = 46
    static let textX: CGFloat = 196
    /// Above a module's trellis bar, room for the stem; the bar's height.
    static let barGap: CGFloat = 34
    static let barHeight: CGFloat = 14
    /// How far a row's drawing may reach above and below the row (leaves, tendrils).
    static let overhang: CGFloat = 80

    static func stemX(_ k: Double) -> CGFloat { stemMid + sway * CGFloat(sin(k * 1.3 + 0.4)) }
    /// The stem zig-zags a little at each node, as a real shoot does.
    static func kink(_ k: Int) -> CGFloat { k % 2 == 1 ? 3 : -3 }
}

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
            let per = max(4, Int(hypot(p2.x - p1.x, p2.y - p1.y) / 4))
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

// MARK: - Where the stem runs

extension VineMetrics {
    /// The stem's points for one module, top to bottom, in the module's own coordinates: y = 0
    /// at the top of its top lesson row, rows `h` tall, then the trellis bar and the card.
    /// Above the module: on into the card above (hidden), or, for the last module, on up the
    /// left to the supra table (`topHeight`: the top picture's height, for its own drawing).
    static func points(firstIndex k0: Int, count n: Int, rowHeight h: CGFloat, isTop: Bool, topHeight: CGFloat? = nil) -> [VinePoint] {
        let kLast = k0 + n - 1
        func node(_ i: Int) -> VinePoint {
            let k = k0 + i
            return VinePoint(x: stemX(Double(k)) + kink(k), y: CGFloat(n - 1 - i) * h + h / 2 - 16, u: Double(k), isNode: true)
        }
        var pts: [VinePoint] = []
        if isTop {
            if let topHeight { pts.append(VinePoint(x: 30, y: -(topHeight - 70), u: Double(kLast) + 3)) }
            pts.append(VinePoint(x: 34, y: -260, u: Double(kLast) + 2.2))
            pts.append(VinePoint(x: 50, y: -140, u: Double(kLast) + 1.4))
            pts.append(VinePoint(x: stemX(Double(kLast) + 0.5) - 2, y: -50, u: Double(kLast) + 0.6))
        } else {
            pts.append(VinePoint(x: stemX(Double(kLast) + 0.5), y: -70, u: Double(kLast) + 0.6))
        }
        for i in (0..<n).reversed() {
            let p = node(i)
            pts.append(p)
            if i > 0 {
                let k = k0 + i - 1
                pts.append(VinePoint(x: (stemX(Double(k)) + stemX(Double(k + 1))) / 2 - kink(k), y: p.y + h / 2,
                                     u: Double(k) + 0.5, isNode: true))
            }
        }
        let barTop = CGFloat(n) * h + barGap
        pts.append(VinePoint(x: stemX(Double(k0) - 0.5), y: barTop + barHeight / 2 + 30, u: Double(k0) - 0.6))
        pts.append(VinePoint(x: stemX(Double(k0) - 1), y: barTop + 300, u: Double(k0) - 1.2))
        return pts
    }
}

extension Array where Element == VinePoint {
    func shifted(by dy: CGFloat) -> [VinePoint] { map { var p = $0; p.y += dy; return p } }
}

// MARK: - One lesson on the vine

/// Where a lesson is on the vine and what it looks like.
struct VineSpot {
    let lesson: Lesson
    let index: Int            // in the whole course
    let indexInModule: Int
    let moduleFirst: Int
    let moduleCount: Int
    let isTopModule: Bool
    let state: LessonState
    let vine: VineState

    /// Grapes ripen: the lesson just done is green, the one before blushing, older ones ripe.
    var bunch: String {
        let age = vine.next.map { Int($0) - index } ?? 99
        let ripe = age == 1 ? "Green" : (age == 2 ? "Blush" : "Purple")
        return "VineBunch\(ripe)\(index % 3 + 1)"
    }
}

struct VineLessonRow: View {
    let spot: VineSpot
    let rowHeight: CGFloat
    let showsPerch: Bool
    let perchSpace: Namespace.ID
    let onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var h: CGFloat { rowHeight }
    private var k: Int { spot.index }
    private var node: CGPoint { CGPoint(x: VineMetrics.stemX(Double(k)) + VineMetrics.kink(k), y: h / 2 - 16) }
    private var itemX: CGFloat { VineMetrics.stemX(Double(k)) + VineMetrics.itemDX }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: VineMetrics.textX)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.lesson.title)
                            .font(.headlineRounded)
                            .foregroundStyle(spot.state == .locked ? Palette.inkFaint : Palette.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Text(spot.lesson.subtitle)
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 16)
                }
                .frame(height: h)
                picture
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .frame(height: h)
        .background(alignment: .topLeading) { growth }
        .overlay(alignment: .topLeading) {
            if showsPerch {
                Image("VinePerch")
                    .resizable()
                    .frame(width: 90, height: 110)
                    .matchedGeometryEffect(id: "ara-perch", in: perchSpace)
                    .offset(x: node.x - 3 - 88, y: h / 2 + 22 - 80)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    /// The lesson's own picture: a leaf (up next or open), a bunch (done) or a bud (locked).
    @ViewBuilder private var picture: some View {
        switch spot.state {
        case .current:
            Image("VineLeafNext").resizable().frame(width: 100, height: 100)
                .scaleEffect(pulse ? 1.04 : 0.97)
                .offset(x: itemX - 50, y: h / 2 + 2 - 50)
                .accessibilityHidden(true)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
                }
        case .available:
            Image("VineLeafOpen").resizable().frame(width: 80, height: 80)
                .rotationEffect(.degrees(k % 2 == 1 ? 6 : -6))
                .offset(x: itemX - 40, y: h / 2 + 2 - 40)
                .accessibilityHidden(true)
        case .completed:
            Image(spot.bunch).resizable().frame(width: 90, height: 90)
                .rotationEffect(.degrees(k % 2 == 1 ? 4 : -4))
                .offset(x: itemX - 45, y: h / 2 + 4 - 45)
                .accessibilityHidden(true)
        case .locked:
            Image("VineBud").resizable().frame(width: 30, height: 30)
                .offset(x: node.x + 20 - 15, y: node.y - 9 - 15)
                .accessibilityHidden(true)
        }
    }

    /// The stem through this row, its node, the leaf or tendril opposite, and the node between
    /// this lesson and the one below.
    private var growth: some View {
        let ink = VineInk.of(scheme)
        let spot = self.spot
        let h = self.h
        let pad = VineMetrics.overhang
        let rowTop = CGFloat(spot.moduleCount - 1 - spot.indexInModule) * h
        let points = VineMetrics.points(firstIndex: spot.moduleFirst, count: spot.moduleCount, rowHeight: h, isTop: spot.isTopModule)
            .shifted(by: -rowTop + pad)
        let node = CGPoint(x: self.node.x, y: self.node.y + pad)
        let itemX = self.itemX
        return Canvas { ctx, size in
            // Stalks, leaves and tendrils first, so the stem sits over where they join it.
            let k = spot.index
            let m = spot.vine.wood(Double(k))
            if spot.indexInModule > 0 {
                let kk = k - 1
                let b = CGPoint(x: (VineMetrics.stemX(Double(kk)) + VineMetrics.stemX(Double(k))) / 2 - VineMetrics.kink(kk), y: node.y + h / 2)
                let mb = spot.vine.wood(Double(kk) + 0.5)
                if kk % 3 != 2 {
                    VineGrowth.tendril(&ctx, kk % 4 == 1 ? 4 : kk % 3 + 1, at: CGPoint(x: b.x + 2, y: b.y),
                                       length: CGFloat(44 + (kk % 2) * 8), degrees: Double(-30 + (kk % 3) * 22))
                } else {
                    VineGrowth.tendril(&ctx, kk % 3 + 1, at: CGPoint(x: b.x - 4, y: b.y - 6), length: 50,
                                       degrees: Double(200 + (kk % 2) * 25))
                }
                let young = spot.vine.next.map { Double(kk) + 0.5 > $0 + 1.5 } ?? false
                let leaf = CGPoint(x: b.x - 34 - CGFloat(kk % 2) * 6, y: b.y + 8)
                VineGrowth.stalk(&ctx, from: CGPoint(x: b.x - 2, y: b.y), to: CGPoint(x: leaf.x + 5, y: leaf.y - 12), wood: mb * 0.6, ink: ink, bend: 0.35, width: 2.2)
                if young {
                    VineGrowth.picture(&ctx, "VineLeafYoung\(kk % 3 + 1)", at: leaf, size: CGFloat(24 + (kk % 3) * 5) * 40 / 28,
                                       degrees: Double(40 + (kk % 2) * 15))
                } else {
                    VineGrowth.picture(&ctx, "VineLeaf\((kk + 2) % 6 + 1)", at: leaf, size: CGFloat(30 + (kk % 3) * 5) * 60 / 44,
                                       degrees: Double(40 + (kk % 2) * 15))
                }
            }
            switch spot.state {
            case .locked:
                VineGrowth.stalk(&ctx, from: CGPoint(x: node.x + 2, y: node.y + 2), to: CGPoint(x: node.x + 16, y: node.y - 4), wood: m, ink: ink, bend: -0.2, width: 2.2)
                VineGrowth.stalk(&ctx, from: CGPoint(x: node.x - 2, y: node.y), to: CGPoint(x: node.x - 18, y: node.y - 10), wood: m, ink: ink, bend: 0.25, width: 2)
                VineGrowth.picture(&ctx, "VineLeafYoung\(k % 3 + 1)", at: CGPoint(x: node.x - 24, y: node.y - 4),
                                   size: CGFloat(20 + (k % 3) * 3) * 40 / 28, degrees: 50)
            default:
                VineGrowth.stalk(&ctx, from: CGPoint(x: node.x + 2, y: node.y), to: CGPoint(x: itemX - 2, y: pad + h / 2 - 32), wood: m, ink: ink, bend: -0.25, width: 3)
                if spot.state != .current {
                    let leaf = CGPoint(x: node.x - 30 - CGFloat(k % 3) * 4, y: node.y - 4 + CGFloat(k % 2) * 6)
                    VineGrowth.stalk(&ctx, from: CGPoint(x: node.x - 2, y: node.y), to: CGPoint(x: leaf.x + 6, y: leaf.y - 12), wood: m * 0.6, ink: ink, bend: 0.3, width: 2.4)
                    VineGrowth.picture(&ctx, "VineLeaf\(k % 6 + 1)", at: leaf, size: CGFloat(38 + (k % 4) * 4) * 60 / 44,
                                       degrees: Double(30 + (k % 3) * 12))
                }
            }
            // The stem, only within this row (the rows above and below draw their own parts).
            var stem = ctx
            stem.clip(to: Path(CGRect(x: 0, y: pad, width: size.width, height: h)))
            VineStem.draw(&stem, points: points, band: pad...(pad + h), state: spot.vine, ink: ink)
        }
        .frame(height: h + 2 * pad)
        .offset(y: -pad)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - A module's base: the trellis bar and the card hanging from it

struct VineModuleBase<Card: View>: View {
    let firstIndex: Int
    let count: Int
    let isTopModule: Bool
    let rowHeight: CGFloat
    let vine: VineState
    @ViewBuilder let card: () -> Card
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = VineInk.of(scheme)
        VStack(spacing: 0) {
            Color.clear.frame(height: VineMetrics.barGap)
            TrellisBar(coilX: VineMetrics.stemX(Double(firstIndex) - 0.5), wood: vine.wood(Double(firstIndex) - 0.6), ink: ink)
                .frame(height: VineMetrics.barHeight)
            card()
                .padding(.top, 18)
                .overlay(alignment: .top) {
                    // Two ropes from the bar to the card.
                    GeometryReader { geo in
                        ForEach([CGFloat(56), geo.size.width - 56], id: \.self) { x in
                            Capsule().fill(ink.rope.color).frame(width: 2.4, height: 24).position(x: x, y: 8)
                            Circle().fill(ink.rope.color).frame(width: 7, height: 7).position(x: x, y: -3)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .background(alignment: .top) {
            GeometryReader { geo in
                let pts = VineMetrics.points(firstIndex: firstIndex, count: count, rowHeight: rowHeight, isTop: isTopModule)
                    .shifted(by: -CGFloat(count) * rowHeight)
                Canvas { ctx, size in
                    VineStem.draw(&ctx, points: pts, band: 0...size.height, state: vine, ink: ink)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// A wooden trellis bar across the screen, with grain, pegs and tendrils wound round it.
struct TrellisBar: View {
    let coilX: CGFloat
    let wood: Double
    let ink: VineInk

    var body: some View {
        Canvas { ctx, size in
            let y: CGFloat = 6, h = VineMetrics.barHeight
            let bar = CGRect(x: -12, y: y, width: size.width + 24, height: h)
            ctx.fill(Path(roundedRect: bar.offsetBy(dx: 0, dy: 2), cornerRadius: h / 2.6), with: .color(ink.woodDeep.color))
            ctx.fill(Path(roundedRect: bar, cornerRadius: h / 2.6), with: .color(ink.wood.color))
            ctx.fill(Path(roundedRect: CGRect(x: 4, y: y + 2.5, width: size.width - 8, height: h * 0.22), cornerRadius: 1.5),
                     with: .color(ink.woodLight.color.opacity(0.6)))
            var gx: CGFloat = 30
            while gx < size.width - 20 {
                var p = Path()
                p.move(to: CGPoint(x: gx, y: y + h * 0.62))
                p.addQuadCurve(to: CGPoint(x: gx + 24, y: y + h * 0.62), control: CGPoint(x: gx + 12, y: y + h * 0.62 - 2))
                ctx.stroke(p, with: .color(ink.woodDeep.color.opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                gx += 47
            }
            for px in [CGFloat(9), size.width - 9] {
                ctx.fill(Path(ellipseIn: CGRect(x: px - 2.6, y: y + h / 2 - 2.6, width: 5.2, height: 5.2)), with: .color(ink.woodDeep.color))
            }
            // Tendrils wound round the bar beside the stem.
            let coil = ink.shoot.mix(ink.cane, smoothstep(0.4, 0.9, wood)).color
            for (x0, turns) in [(coilX + 14, 3), (coilX - 36, 2)] {
                for i in 0..<turns {
                    let xx = x0 + CGFloat(i) * 5.5
                    var p = Path()
                    p.move(to: CGPoint(x: xx - 2, y: y + h + 1.5))
                    p.addCurve(to: CGPoint(x: xx + 4, y: y + h * 0.15), control1: CGPoint(x: xx - 5, y: y + h * 0.3), control2: CGPoint(x: xx + 1, y: y - 3.5))
                    ctx.stroke(p, with: .color(coil), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        }
        .frame(height: VineMetrics.barHeight + 12)
        .padding(.vertical, -6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - The top of the vine: the supra table

struct VineTop: View {
    let lastModuleFirst: Int
    let lastModuleCount: Int
    let rowHeight: CGFloat
    let vine: VineState
    let finished: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let ink = VineInk.of(scheme)
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
        .padding(.top, 12)
        .padding(.bottom, 40)
        .accessibilityElement(children: .combine)
        .background(alignment: .top) {
            GeometryReader { geo in
                let pts = VineMetrics.points(firstIndex: lastModuleFirst, count: lastModuleCount, rowHeight: rowHeight,
                                             isTop: true, topHeight: geo.size.height)
                    .shifted(by: geo.size.height)
                Canvas { ctx, size in
                    VineStem.draw(&ctx, points: pts, band: 0...size.height, state: vine, ink: ink)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
