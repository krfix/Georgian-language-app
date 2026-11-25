"""The grapevine Learn path as geometry (docs/vine-path.md, KART #15).

Cartoon, but true to how a grapevine grows (studied in KART #15):
- The vine is one stem that tapers from the old trunk to the shoot's tip. It turns woody from
  the bottom up: green, then yellow, then brown, in patches (the bark, or periderm, forms in
  blotches before it closes), with shaggy strips on the old wood.
- It grows in nodes: a slight swelling with a leaf. Opposite each leaf: a grape bunch on the
  lower nodes, a forked tendril higher up (two nodes with a tendril, then one without).
  Tendrils coil like springs round whatever they catch.
- The tip never stops: it bends over like a shepherd's crook with small bronze leaves unfolding.
- Grapes start green and colour (veraison) as the stem turns brown: here a lesson just
  finished is a green bunch (like Rkatsiteli), and it ripens to Saperavi purple.

Lessons on the vine: done = a bunch (green, blushing, ripe), up next = a fresh leaf with a
glow, open = a calmer leaf, locked = a small closed bud. Every part is drawn around its own
centre in points, with a seed for its small variations, so the pictures stay the same run to
run. Light and dark come from VINE_COLOURS.
"""
import math
import random

import ara

VINE_COLOURS = {
    "light": dict(
        bark="#6B4A30", bark_deep="#46301E", bark_light="#9C7650", bark_strip="#553922",
        cane="#A0764B", straw="#C9B15C",                                  # one-year wood, the yellow stage
        shoot="#7DB65A", shoot_deep="#4E8A36", shoot_light="#B5DB8E", tip="#C8674E",
        node="#5A3E28",
        leaf="#3FAE5E", leaf_deep="#22843F", leaf_light="#7DD08A", vein="#C9F0CF",
        leaf_open="#6DBF7F", leaf_open_deep="#3F9257",
        deco=("#4DA75A", "#5FB463", "#3E9A55", "#6CBB6A"), deco_deep="#2E7A40",
        young="#B7C95C", young_light="#E2EC9A", young_deep="#B0703A",
        bud="#B9CFA6", bud_deep="#8FAA7C",
        purple="#6E35B5", purple_deep="#4A1F86", purple_light="#A877E8",
        green="#A6CF4E", green_deep="#6C9A26", green_light="#E3F5A0",
        blush="#B0577E", bloom="#F2EAFB",
        glow="#3FAE5E", rope="#C8A77A",
        wood="#7B5638", wood_deep="#5A3B24", wood_light="#A57A52",          # the trellis
        bg_top="#FFF7EF", bg_bottom="#F6EBDD", ink="#24182A", soft="#6F6274", faint="#B3A8B6",
    ),
    "dark": dict(
        bark="#8C6748", bark_deep="#5A3F2A", bark_light="#B8926A", bark_strip="#6E4E34",
        cane="#B48A5C", straw="#B9A456",
        shoot="#6FAE52", shoot_deep="#3F7A2E", shoot_light="#A2D47F", tip="#D9785E",
        node="#6E4E34",
        leaf="#4FC46E", leaf_deep="#2C9149", leaf_light="#8FE09B", vein="#D8F7DC",
        leaf_open="#5E9F6C", leaf_open_deep="#3D7A4E",
        deco=("#3F8A4C", "#4C9655", "#367F47", "#58A05A"), deco_deep="#25603A",
        young="#9DB04E", young_light="#C9D87E", young_deep="#A0663A",
        bud="#5D6E52", bud_deep="#45543D",
        purple="#9B62E6", purple_deep="#6A35B0", purple_light="#C9A2FF",
        green="#B4DA5C", green_deep="#78A830", green_light="#EAF8B4",
        blush="#C46C93", bloom="#F6F0FF",
        glow="#5AD585", rope="#A8875C",
        wood="#9C7350", wood_deep="#6E4C31", wood_light="#C49A6E",
        bg_top="#1B1424", bg_bottom="#120E18", ink="#FFF7EF", soft="#BFB2C6", faint="#6C6075",
    ),
}


def _f(x, y):
    return f"{x:.2f},{y:.2f}"


def mix(a, b, t):
    """Two #RRGGBB colours mixed, t = 0 gives a, 1 gives b."""
    t = max(0.0, min(1.0, t))
    pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(pa, pb))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def smooth_d(pts, closed=True):
    """A smooth path through points (Catmull-Rom turned into cubic curves)."""
    n = len(pts)
    d = f"M{_f(*pts[0])}"
    for i in (range(n) if closed else range(n - 1)):
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[0]
        p1, p2 = pts[i], pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else pts[-1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{_f(*c1)} {_f(*c2)} {_f(*p2)}"
    return d + ("Z" if closed else "")


def sample(pts, step=5):
    """Points along the smooth curve through pts (Catmull-Rom), about `step` points apart."""
    out, n = [], len(pts) - 1
    for i in range(n):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(n, i + 2)]
        per = max(4, int(math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / step))
        for j in range(per):
            t = j / per
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    out.append(pts[-1])
    return out


def _normals(s):
    out = []
    for i in range(len(s)):
        q0, q1 = s[max(0, i - 1)], s[min(len(s) - 1, i + 1)]
        dx, dy = q1[0] - q0[0], q1[1] - q0[1]
        ln = math.hypot(dx, dy) or 1
        out.append((-dy / ln, dx / ln))
    return out


# ---------------------------------------------------------------------------------------
# The stem: one tapering shape whose colour follows how woody it is

def stem_colour(c, m):
    """The stem's colour at woodiness m: 0 green shoot, 0.45 yellow straw, 0.7 cane, 1 bark."""
    if m < 0.45:
        return mix(c["shoot"], c["straw"], m / 0.45)
    if m < 0.7:
        return mix(c["straw"], c["cane"], (m - 0.45) / 0.25)
    return mix(c["cane"], c["bark"], (m - 0.7) / 0.3)


def edge_colour(c, m):
    return mix(c["shoot_deep"], c["bark_deep"], smoothstep(0.2, 0.8, m))


def stem_svg(pts, widths, wood, c, seed=1):
    """The stem through pts (bottom to top). widths(p) and wood(p), for a point p on it, give
    the width in points and the woodiness (0 green to 1 old bark). Drawn as short
    quads so width and colour change smoothly; then the patches of new bark, the bark's
    strips on old wood and a light streak down the stem."""
    rnd = random.Random(seed)
    s = sample(pts)
    n = len(s)
    nm = _normals(s)
    ws = [widths(p) for p in s]
    ms = [wood(p) for p in s]

    def quad(i, extra):
        a, b = s[i], s[i + 1]
        wa, wb = ws[i] / 2 + extra, ws[i + 1] / 2 + extra
        na, nb = nm[i], nm[i + 1]
        return (f"M{_f(a[0] + na[0] * wa, a[1] + na[1] * wa)} L{_f(b[0] + nb[0] * wb, b[1] + nb[1] * wb)} "
                f"L{_f(b[0] - nb[0] * wb, b[1] - nb[1] * wb)} L{_f(a[0] - na[0] * wa, a[1] - na[1] * wa)}Z")

    out = ""
    for i in range(n - 1):                                     # the cartoon outline
        col = edge_colour(c, ms[i])
        out += f'<path d="{quad(i, 1.4)}" fill="{col}" stroke="{col}" stroke-width="0.8" stroke-linejoin="round"/>'
    out += f'<circle cx="{s[-1][0]:.2f}" cy="{s[-1][1]:.2f}" r="{ws[-1] / 2 + 1.4:.2f}" fill="{edge_colour(c, ms[-1])}"/>'
    for i in range(n - 1):
        col = stem_colour(c, ms[i])
        out += f'<path d="{quad(i, 0)}" fill="{col}" stroke="{col}" stroke-width="0.7" stroke-linejoin="round"/>'
    out += f'<circle cx="{s[-1][0]:.2f}" cy="{s[-1][1]:.2f}" r="{ws[-1] / 2:.2f}" fill="{stem_colour(c, ms[-1])}"/>'
    # The bark forming: brown blotches where the stem is turning.
    for i in range(2, n - 2, 3):
        m = ms[i]
        if 0.3 < m < 0.85 and rnd.random() < 0.55:
            k = rnd.uniform(-0.18, 0.18)
            x, y = s[i][0] + nm[i][0] * ws[i] * k, s[i][1] + nm[i][1] * ws[i] * k
            ang = math.degrees(math.atan2(s[i + 1][1] - s[i - 1][1], s[i + 1][0] - s[i - 1][0]))
            rx, ry = rnd.uniform(6, 12) * (0.5 + m), ws[i] * rnd.uniform(0.1, 0.18)
            out += (f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{rx:.2f}" ry="{ry:.2f}" transform="rotate({ang:.1f} {x:.2f} {y:.2f})" '
                    f'fill="{c["cane"] if m < 0.6 else c["bark"]}" opacity="{0.3 + 0.4 * m:.2f}"/>')
    # Shaggy strips on old bark: wavy, torn lines along the stem, fading in with woodiness.
    for lane in (-0.28, -0.06, 0.16, 0.33):
        phase = rnd.uniform(0, 6)
        for i in range(n - 1):
            if ms[i] < 0.75 or (i + int(phase * 3)) % 13 == 0:
                continue
            op = smoothstep(0.75, 0.95, ms[i]) * 0.8
            wob = lambda j: lane + 0.05 * math.sin(j * 0.3 + phase)  # noqa: E731
            a = (s[i][0] + nm[i][0] * ws[i] * wob(i), s[i][1] + nm[i][1] * ws[i] * wob(i))
            b = (s[i + 1][0] + nm[i + 1][0] * ws[i + 1] * wob(i + 1), s[i + 1][1] + nm[i + 1][1] * ws[i + 1] * wob(i + 1))
            out += (f'<path d="M{_f(*a)} L{_f(*b)}" stroke="{c["bark_strip"] if lane < 0.1 else c["bark_light"]}" '
                    f'stroke-width="{1.3 if lane < 0.1 else 1.0}" stroke-linecap="round" opacity="{op:.2f}"/>')
    # A light streak down one side of the young stem, for roundness: one line, fading out
    # where the bark closes.
    streak = [(s[i][0] - nm[i][0] * ws[i] * 0.22, s[i][1] - nm[i][1] * ws[i] * 0.22) for i in range(n) if ms[i] < 0.6]
    if len(streak) > 1:
        wavg = sum(ws[i] for i in range(n) if ms[i] < 0.6) / len(streak)
        out += (f'<path d="M{" L".join(_f(*q) for q in streak)}" stroke="{c["shoot_light"]}" stroke-width="{wavg * 0.15:.2f}" '
                f'fill="none" stroke-linecap="round" stroke-linejoin="round" opacity="0.5"/>')
    return out


def node_svg(x, y, w, ang, c, m):
    """A node: the slight swelling where a leaf grows (a bulge in the stem's own colour with
    a soft darker rim), darker as the stem gets woody."""
    body = stem_colour(c, m)
    rim = mix(edge_colour(c, m), body, 0.35)
    return (f'<ellipse cx="{x:.2f}" cy="{y:.2f}" rx="{w * 0.56 + 0.8:.2f}" ry="{max(2.2, w * 0.22):.2f}" '
            f'transform="rotate({ang:.1f} {x:.2f} {y:.2f})" fill="{body}" stroke="{rim}" stroke-width="1" stroke-opacity="0.6"/>')


# ---------------------------------------------------------------------------------------
# Leaves: five lobes, a notch at the stalk, a toothed edge, each a little different

def leaf_shape_wide(seed):
    """A leaf shape from a wider range: some deeply cut, some nearly round, some lopsided."""
    r = random.Random(seed)
    return dict(lobe=r.uniform(0.7, 1.45), sinus=r.uniform(0.3, 2.6), teeth=r.choice((18, 20, 22, 24, 26, 30)),
                tooth=r.uniform(0.03, 0.08), asym=r.uniform(-0.16, 0.16), stretch=r.uniform(0.85, 1.15))


def leaf_shape(seed):
    r = random.Random(seed)
    return dict(lobe=r.uniform(0.8, 1.25), sinus=r.uniform(0.6, 1.6), teeth=r.choice((20, 22, 24, 26)),
                tooth=r.uniform(0.035, 0.06), asym=r.uniform(-0.1, 0.1), stretch=r.uniform(0.9, 1.1))


PLAIN = dict(lobe=1.0, sinus=1.0, teeth=26, tooth=0.05, asym=0.0, stretch=1.0)


def _leaf_r(phi, sh=PLAIN):
    """Radius of the leaf at angle phi (degrees from straight down, the main lobe)."""
    g = lambda c, w: math.exp(-((phi - c) / w) ** 2)  # noqa: E731
    L, S = sh["lobe"], sh["sinus"]
    r = 0.74
    r += L * (0.28 * g(0, 30) + 0.22 * (g(66, 28) * (1 + sh["asym"]) + g(-66, 28) * (1 - sh["asym"]))
              + 0.12 * (g(126, 26) + g(-126, 26)))
    r -= S * (0.07 * (g(34, 8) + g(-34, 8)) + 0.06 * (g(98, 8) + g(-98, 8)))
    r -= 0.40 * (g(180, 20) + g(-180, 20))
    return r


def _leaf_pts(cx, cy, size, rot, sh):
    n = sh["teeth"] * 8
    st = sh["stretch"] ** 0.5
    pts = []
    for i in range(n):
        phi = -180 + 360 * i / n
        k = (i % 8) / 8
        tooth = sh["tooth"] * (k if k < 0.75 else (1 - k) * 3)
        r = (_leaf_r(phi, sh) + tooth) * size / 2.2
        # In the leaf's own frame (main lobe pointing down), stretched, then turned by rot.
        lx, ly = r * math.cos(math.radians(phi + 90)) * st, r * math.sin(math.radians(phi + 90)) / st
        a = math.radians(rot)
        pts.append((phi, cx + lx * math.cos(a) - ly * math.sin(a), cy + lx * math.sin(a) + ly * math.cos(a)))
    return pts


def leaf_d(cx, cy, size, rot=0.0, sh=PLAIN, half=0):
    """The leaf's outline, or with half=1 the half on one side of the midrib (for shading)."""
    pts = _leaf_pts(cx, cy, size, rot, sh)
    if half:
        pts = [p for p in pts if p[0] >= 0]
        return "M" + _f(cx, cy) + " L" + " L".join(_f(x, y) for _, x, y in pts) + "Z"
    return "M" + " L".join(_f(x, y) for _, x, y in pts) + "Z"


def leaf_svg(cx, cy, size, c, kind="next", rot=0.0, uid="l", sh=PLAIN, colour=None):
    """A leaf hanging from its stalk at the top. kind: 'next' (bright, veined, a soft glow),
    'open' (calmer), 'deco' (a leaf of the vine, colour given), 'young' (bronze, unfolding)."""
    if kind == "next":
        base, deep, light, vein = c["leaf"], c["leaf_deep"], c["leaf_light"], c["vein"]
    elif kind == "open":
        base, deep, light, vein = c["leaf_open"], c["leaf_open_deep"], c["leaf_open"], c["leaf_light"]
    elif kind == "young":
        base, deep, light = c["young"], c["young_deep"], c["young_light"]       # bronze at the edges
        vein = mix(c["young_light"], "#FFFFFF", 0.3)
    else:
        base = colour or c["deco"][0]
        deep, light, vein = c["deco_deep"], mix(base, "#FFFFFF", 0.22), mix(base, "#FFFFFF", 0.42)
    edge = mix(deep, "#000000", 0.25)
    out = ""
    if kind == "next":
        out += (f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{size * 0.68:.2f}" fill="{c["glow"]}" opacity="0.16"/>'
                f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{size * 0.58:.2f}" fill="none" stroke="{c["glow"]}" '
                f'stroke-width="{size * 0.04:.2f}" opacity="0.35"/>')
    out += (f'<defs><radialGradient id="{uid}" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="{light}"/>'
            f'<stop offset="0.55" stop-color="{base}"/><stop offset="1" stop-color="{deep}"/></radialGradient></defs>')
    out += (f'<path d="{leaf_d(cx, cy, size, rot, sh)}" fill="url(#{uid})" stroke="{edge}" '
            f'stroke-width="{max(0.8, size * 0.018):.2f}" stroke-linejoin="round"/>')
    # One half a shade darker, as if the leaf were folded a little along its midrib.
    out += f'<path d="{leaf_d(cx, cy, size, rot, sh, half=1)}" fill="{deep}" opacity="0.2"/>'
    a0 = math.radians(rot)
    rot_p = lambda lx, ly: (cx + lx * math.cos(a0) - ly * math.sin(a0), cy + lx * math.sin(a0) + ly * math.cos(a0))  # noqa: E731
    rx, ry = rot_p(0, -size * 0.12)
    for phi, k in ((0, 0.84), (66, 0.8), (-66, 0.8), (126, 0.7), (-126, 0.7)):
        rr = size / 2.2 * _leaf_r(phi, sh) * k
        tx, ty = rot_p(rr * math.cos(math.radians(phi + 90)), rr * math.sin(math.radians(phi + 90)))
        mx, my = (rx + tx) / 2 + (ty - ry) * 0.06, (ry + ty) / 2 - (tx - rx) * 0.06
        out += (f'<path d="M{_f(rx, ry)} Q{_f(mx, my)} {_f(tx, ty)}" stroke="{vein}" stroke-width="{max(0.7, size * 0.03):.2f}" '
                f'fill="none" stroke-linecap="round" opacity="{0.85 if kind == "next" else 0.6}"/>')
    return out


def stalk_svg(x0, y0, x1, y1, c, m=0.0, bend=0.3, w=2.6):
    """A leaf's or a bunch's stalk from the node to it, bowing a little."""
    mx, my = (x0 + x1) / 2 + (y1 - y0) * bend, (y0 + y1) / 2 - (x1 - x0) * bend
    col = mix(c["shoot_deep"], c["cane"], m)
    return f'<path d="M{_f(x0, y0)} Q{_f(mx, my)} {_f(x1, y1)}" stroke="{col}" stroke-width="{w}" fill="none" stroke-linecap="round"/>'


# ---------------------------------------------------------------------------------------
# Grape bunches: green when just finished, blushing, then ripe purple

def bunch_top(cx, cy, size, tilt=0.0):
    """Where a bunch's stalk ends: a point hidden behind its top grapes, turned with the
    bunch. The bunch has no stem of its own; the stalk from the vine runs to here and the
    grapes cover its end, so it meets the bunch however it is turned (owner, KART #15)."""
    t = math.radians(tilt)
    return cx + size * BUNCH_TOP * math.sin(t), cy - size * BUNCH_TOP * math.cos(t)


BUNCH_TOP = 0.26   # of the bunch's size above its centre: between the first and second row


def bunch_svg(cx, cy, size, c, uid="g", ripe="purple", seed=3, tilt=0.0):
    """A bunch about `size` points tall centred on (cx, cy): a cone of grapes with a shoulder
    (a small side wing), each grape a little different. ripe: green, blush or purple. No stem:
    draw its stalk first, to bunch_top()."""
    rnd = random.Random(seed)
    s = size
    r = s * 0.13
    rows = [4, 4, 3, 3, 2, 1] if rnd.random() < 0.5 else [4, 3, 3, 2, 2, 1]
    grapes = []
    y = -0.34
    lean = 0.03 if seed % 2 else -0.03
    for ri, k in enumerate(rows):
        for j in range(k):
            x = (j - (k - 1) / 2) * 0.235 + rnd.uniform(-0.025, 0.025) + lean * ri
            grapes.append((x, y + rnd.uniform(-0.02, 0.02), rnd.uniform(0.9, 1.08)))
        y += 0.16
    wing = 1 if rnd.random() < 0.5 else -1                                # the shoulder
    for x, y in ((0.5, -0.28), (0.58, -0.13)):
        grapes.append((x * wing, y, rnd.uniform(0.85, 0.98)))
    t = math.radians(tilt)
    out = ""
    for name, (l, m, d) in (("purple", (c["purple_light"], c["purple"], c["purple_deep"])),
                            ("green", (c["green_light"], c["green"], c["green_deep"])),
                            ("blush", (c["green_light"], c["blush"], c["purple_deep"]))):
        out += (f'<defs><radialGradient id="{uid}{name}" cx="0.35" cy="0.3" r="0.75"><stop offset="0" stop-color="{l}"/>'
                f'<stop offset="0.55" stop-color="{m}"/><stop offset="1" stop-color="{d}"/></radialGradient></defs>')
    for (x, y, k) in sorted(grapes, key=lambda q: q[1]):
        x, y = x * math.cos(t) - y * math.sin(t), x * math.sin(t) + y * math.cos(t)
        gx, gy, gr = cx + x * s, cy + y * s, r * k
        kind = ripe
        if ripe == "blush":                    # colouring from the top of the bunch down, a few at a time
            p = rnd.random()
            kind = "purple" if p < 0.35 - y * 0.6 else ("blush" if p < 0.8 - y * 0.3 else "green")
        deep = c["green_deep"] if kind == "green" else c["purple_deep"]
        out += (f'<circle cx="{gx:.2f}" cy="{gy:.2f}" r="{gr:.2f}" fill="url(#{uid}{kind})" '
                f'stroke="{mix(deep, "#000000", 0.2)}" stroke-width="{max(0.7, s * 0.012):.2f}"/>')
        out += f'<circle cx="{gx - gr * 0.35:.2f}" cy="{gy - gr * 0.38:.2f}" r="{gr * 0.22:.2f}" fill="{c["bloom"]}" opacity="0.75"/>'
    return out


# ---------------------------------------------------------------------------------------
# Buds, tendrils, the growing tip

def bud_svg(cx, cy, size, c):
    """A small closed bud, `size` points tall, pointing up."""
    s = size
    body = smooth_d([(cx, cy - s * 0.5), (cx + s * 0.3, cy - s * 0.05), (cx + s * 0.22, cy + s * 0.32),
                     (cx, cy + s * 0.42), (cx - s * 0.22, cy + s * 0.32), (cx - s * 0.3, cy - s * 0.05)])
    fold = f'M{_f(cx, cy - s * 0.5)} Q{_f(cx - s * 0.08, cy)} {_f(cx - s * 0.02, cy + s * 0.4)}'
    return (f'<path d="{body}" fill="{c["bud"]}" stroke="{c["bud_deep"]}" stroke-width="{s * 0.06:.2f}"/>'
            f'<path d="{fold}" stroke="{c["bud_deep"]}" stroke-width="{s * 0.06:.2f}" fill="none" stroke-linecap="round"/>')


def _curl(x, y, ang, r0, turns, side):
    """A flat spiral starting at (x, y) heading at ang degrees, curling to `side` (+1 or -1)."""
    a = math.radians(ang)
    cx, cy = x + math.cos(a + side * math.pi / 2) * r0, y + math.sin(a + side * math.pi / 2) * r0
    start = math.atan2(y - cy, x - cx)
    n = int(28 * turns)
    pts = []
    for i in range(n + 1):
        t = i / n
        th = start + side * t * turns * 2 * math.pi
        r = r0 * (1 - 0.75 * t)
        pts.append((cx + r * math.cos(th), cy + r * math.sin(th)))
    return pts


def _poly(pts, col, w):
    return (f'<path d="M{" L".join(_f(*p) for p in pts)}" stroke="{col}" stroke-width="{w:.2f}" fill="none" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


def tendril_svg(x, y, size, ang, c, seed=5, colour=None, w=1.9, spring=False, fork=True):
    """A forked tendril from (x, y) heading at ang degrees: a gently bending arm that splits in
    two, each fork ending in a curl; with spring=True the long fork is coiled like a spring;
    with fork=False a single arm ending in one curl."""
    rnd = random.Random(seed)
    col = colour or c["shoot"]
    a = math.radians(ang)
    bend = rnd.uniform(-0.4, 0.4)
    L = size * 0.5
    fx, fy = x + math.cos(a + bend * 0.5) * L, y + math.sin(a + bend * 0.5) * L
    nx, ny = math.cos(a + math.pi / 2), math.sin(a + math.pi / 2)
    mx, my = x + math.cos(a) * L * 0.5 + nx * bend * L * 0.4, y + math.sin(a) * L * 0.5 + ny * bend * L * 0.4
    out = f'<path d="M{_f(x, y)} Q{_f(mx, my)} {_f(fx, fy)}" stroke="{col}" stroke-width="{w}" fill="none" stroke-linecap="round"/>'
    # The upper fork curls up and the lower one down: away from each other, never into one
    # another (where they met they blended into a knot).
    forks = ((-26, 1.0, -1), (34, 0.65, 1)) if fork else ((rnd.uniform(-15, 15), 1.3, -1 if rnd.random() < 0.5 else 1),)
    for k, (da, frac, side) in enumerate(forks):
        aa = ang + da + rnd.uniform(-10, 10)
        ra = math.radians(aa)
        ln = size * 0.3 * frac
        ex, ey = fx + math.cos(ra) * ln, fy + math.sin(ra) * ln
        out += _poly([(fx, fy), (ex, ey)], col, w * 0.85)
        if spring and k == 0:
            pts, n = [], 90
            for i in range(n + 1):
                t = i / n
                th = t * 5 * 2 * math.pi
                rr = size * 0.08 * (1 - 0.45 * t)
                along = size * 0.42 * t
                px = ex + math.cos(ra) * along + (math.cos(th) - 1) * rr * math.cos(ra) - math.sin(th) * rr * 0.75 * math.sin(ra)
                py = ey + math.sin(ra) * along + (math.cos(th) - 1) * rr * math.sin(ra) + math.sin(th) * rr * 0.75 * math.cos(ra)
                pts.append((px, py))
            out += _poly(pts, col, w * 0.72)
        else:
            sd = side
            out += _poly(_curl(ex, ey, aa, size * rnd.uniform(0.14, 0.2) * frac, rnd.uniform(1.4, 2.4), sd), col, w * 0.72)
    return out


def coil_round_bar(x, y, h, colour, turns=3, w=1.8):
    """A tendril wound round a trellis bar at x: loops over the bar (top y, height h)."""
    out = ""
    for i in range(turns):
        xx = x + i * 5.5
        out += (f'<path d="M{_f(xx - 2, y + h + 1.5)} C{_f(xx - 5, y + h * 0.3)} {_f(xx + 1, y - 3.5)} {_f(xx + 4, y + h * 0.15)}" '
                f'stroke="{colour}" stroke-width="{w}" fill="none" stroke-linecap="round"/>')
    return out


def tip_svg(x, y, c, size=26, side=1, uid="tip"):
    """The growing tip of a shoot at (x, y), bending over like a shepherd's crook, with
    small bronze leaves unfolding and a tiny tendril."""
    s = size
    pts = [(x, y), (x + side * s * 0.08, y - s * 0.55), (x + side * s * 0.42, y - s * 0.88),
           (x + side * s * 0.74, y - s * 0.74), (x + side * s * 0.8, y - s * 0.46)]
    d = smooth_d(pts, closed=False)
    out = tendril_svg(x + side * s * 0.1, y - s * 0.35, s * 0.7, -90 - side * 50, c, seed=int(abs(x * 7 + y)), w=1.3)
    out += (f'<path d="{d}" stroke="{c["shoot_deep"]}" stroke-width="{s * 0.15:.2f}" fill="none" stroke-linecap="round"/>'
            f'<path d="{d}" stroke="{mix(c["shoot"], c["tip"], 0.55)}" stroke-width="{s * 0.1:.2f}" fill="none" stroke-linecap="round"/>')
    out += leaf_svg(x + side * s * 0.82, y - s * 0.3, s * 0.42, c, "young", rot=side * -15, uid=uid + "a", sh=leaf_shape(3))
    out += leaf_svg(x + side * s * 0.06, y - s * 0.6, s * 0.5, c, "young", rot=side * 75, uid=uid + "b", sh=leaf_shape(4))
    return out


# ---------------------------------------------------------------------------------------
# The trellis bar and Ara

def trellis_svg(x0, x1, y, c, h=14):
    """A wooden trellis bar from x0 to x1 at height y (its top), with grain and pegs."""
    out = (f'<rect x="{x0:.2f}" y="{y + 2:.2f}" width="{x1 - x0:.2f}" height="{h:.2f}" rx="{h / 2.6:.2f}" fill="{c["wood_deep"]}"/>'
           f'<rect x="{x0:.2f}" y="{y:.2f}" width="{x1 - x0:.2f}" height="{h:.2f}" rx="{h / 2.6:.2f}" fill="{c["wood"]}"/>'
           f'<rect x="{x0 + 4:.2f}" y="{y + 2.5:.2f}" width="{x1 - x0 - 8:.2f}" height="{h * 0.22:.2f}" rx="1.5" fill="{c["wood_light"]}" opacity="0.6"/>')
    for gx in range(int(x0 + 30), int(x1 - 20), 47):
        out += (f'<path d="M{gx},{y + h * 0.62:.2f} q12,-2 24,0" stroke="{c["wood_deep"]}" stroke-width="1.2" fill="none" '
                f'stroke-linecap="round" opacity="0.7"/>')
    for px in (x0 + 9, x1 - 9):
        out += f'<circle cx="{px:.2f}" cy="{y + h / 2:.2f}" r="2.6" fill="{c["wood_deep"]}"/>'
    return out


def perch_svg(stem_x, y, c, R=13.5, pose="hello", reach=46, m=0.4):
    """Ara perched on a short side shoot to the left of the stem at height y, facing the leaf:
    the parrot, then the shoot over its tail (with a small leaf at its end), then its toes."""
    o = ara.POSES[pose]
    a = math.radians(o["lean"])
    fx, fy = 0.15, 2.98
    foot = (fx * math.cos(a) - fy * math.sin(a), fx * math.sin(a) + fy * math.cos(a))
    perch_x = stem_x - reach * 0.6
    cx, cy = perch_x - foot[0] * R, y - foot[1] * R
    x_to = stem_x - reach
    mid = (stem_x + x_to) / 2
    d = f"M{_f(stem_x, y - 7)} Q{_f(mid, y + 1)} {_f(x_to, y + 1)}"
    out = ara.mascot_svg(cx, cy, R, pose)
    out += (f'<path d="{d}" stroke="{edge_colour(c, m)}" stroke-width="6.6" fill="none" stroke-linecap="round"/>'
            f'<path d="{d}" stroke="{stem_colour(c, m)}" stroke-width="4.6" fill="none" stroke-linecap="round"/>')
    out += leaf_svg(x_to - 3, y + 9, 17, c, "deco", rot=35, uid=f"perch{y:.0f}", sh=leaf_shape(int(y)), colour=c["deco"][1])
    for dx in (-0.36 * R, 0.2 * R):
        out += f'<ellipse cx="{perch_x + dx:.2f}" cy="{y - 0.5:.2f}" rx="{R * 0.17:.2f}" ry="{R * 0.22:.2f}" fill="{ara.FOOT}"/>'
    return out
