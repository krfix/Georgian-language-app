"""The grapevine Learn path as geometry (docs/vine-path.md, KART #15).

The Learn path grows from the bottom up as a grapevine. Each lesson sits on the vine:
done = a ripe grape bunch, up next = a fresh green leaf (gently alive), open = a calmer
leaf, locked = a small closed bud. Each module is a level of the vine, its card hanging
from a wooden trellis bar. Ara perches beside the leaf that is up next.

Every part is drawn around its own centre in points, so the same numbers make the parts
sheet, the screen mock-ups and, later, the shapes the app draws (LearnView). Light and
dark come from one table of colours (VINE_COLOURS).
"""
import math

import ara

# Colours for each look. Grapes are always Saperavi (the grape the wine purple is named
# after); leaves are tkemali green; the stem and trellis are vine wood.
VINE_COLOURS = {
    "light": dict(
        wood="#7B5638", wood_deep="#5A3B24", wood_light="#A57A52",       # old stem, trellis
        shoot="#9CC48A", shoot_faint="#D8E6CC",                           # young stem above next
        leaf="#3FAE5E", leaf_deep="#22843F", leaf_light="#7DD08A", vein="#C9F0CF",
        leaf_open="#7CC58C", leaf_open_deep="#4C9E62",
        bud="#B9CFA6", bud_deep="#8FAA7C",
        grape="#6E35B5", grape_deep="#4A1F86", grape_light="#A877E8", bloom="#E9DDFB",
        glow="#3FAE5E", rope="#C8A77A",
        bg_top="#FFF7EF", bg_bottom="#F6EBDD", ink="#24182A", soft="#6F6274", faint="#B3A8B6",
    ),
    "dark": dict(
        wood="#9C7350", wood_deep="#6E4C31", wood_light="#C49A6E",
        shoot="#6FA061", shoot_faint="#3A4A36",
        leaf="#4FC46E", leaf_deep="#2C9149", leaf_light="#8FE09B", vein="#D8F7DC",
        leaf_open="#5E9F6C", leaf_open_deep="#3D7A4E",
        bud="#5D6E52", bud_deep="#45543D",
        grape="#9B62E6", grape_deep="#6A35B0", grape_light="#C9A2FF", bloom="#F1E6FF",
        glow="#5AD585", rope="#A8875C",
        bg_top="#1B1424", bg_bottom="#120E18", ink="#FFF7EF", soft="#BFB2C6", faint="#6C6075",
    ),
}


def _f(x, y):
    return f"{x:.2f},{y:.2f}"


def smooth_d(pts, closed=True):
    """A smooth path through points (Catmull-Rom turned into cubic curves)."""
    n = len(pts)
    d = f"M{_f(*pts[0])}"
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[0]
        p1, p2 = pts[i], pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else pts[-1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{_f(*c1)} {_f(*c2)} {_f(*p2)}"
    return d + ("Z" if closed else "")


# ---------------------------------------------------------------------------------------
# The grape leaf: five lobes, a deep notch where the stalk joins, a toothed edge

def _leaf_r(phi):
    """Radius of the leaf at angle phi (degrees from straight down, the main lobe)."""
    g = lambda c, w: math.exp(-((phi - c) / w) ** 2)  # noqa: E731
    r = 0.74
    r += 0.28 * g(0, 30) + 0.22 * (g(66, 28) + g(-66, 28)) + 0.12 * (g(126, 26) + g(-126, 26))
    r -= 0.07 * (g(34, 8) + g(-34, 8)) + 0.06 * (g(98, 8) + g(-98, 8))   # the sinuses between lobes
    r -= 0.40 * (g(180, 20) + g(-180, 20))                              # the notch at the stalk
    return r


TEETH = 26


def leaf_d(cx, cy, size, rot=0.0):
    """The leaf's outline, `size` points across, hanging down from its stalk (turned by rot)."""
    pts, n = [], TEETH * 8
    for i in range(n):
        phi = -180 + 360 * i / n
        k = (i % 8) / 8                                   # each tooth: a slow rise, a quick drop
        tooth = 0.05 * (k if k < 0.75 else (1 - k) * 3)
        r = (_leaf_r(phi) + tooth) * size / 2.2
        a = math.radians(phi + 90 + rot)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return "M" + " L".join(_f(*p) for p in pts) + "Z"


def leaf_svg(cx, cy, size, c, kind="next", rot=0.0, uid="l"):
    """A leaf: 'next' (bright, veined, a soft glow) or 'open' (calmer)."""
    base = c["leaf"] if kind == "next" else c["leaf_open"]
    deep = c["leaf_deep"] if kind == "next" else c["leaf_open_deep"]
    out = ""
    if kind == "next":
        out += (f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{size * 0.66:.2f}" fill="{c["glow"]}" opacity="0.16"/>'
                f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{size * 0.56:.2f}" fill="none" stroke="{c["glow"]}" '
                f'stroke-width="{size * 0.04:.2f}" opacity="0.35"/>')
    out += (f'<defs><radialGradient id="{uid}" cx="0.4" cy="0.3" r="0.8"><stop offset="0" stop-color="{c["leaf_light"] if kind == "next" else base}"/>'
            f'<stop offset="0.55" stop-color="{base}"/><stop offset="1" stop-color="{deep}"/></radialGradient></defs>')
    out += f'<path d="{leaf_d(cx, cy + size * 0.04, size, rot)}" fill="{deep}"/>'   # a thin darker edge below
    out += f'<path d="{leaf_d(cx, cy, size, rot)}" fill="url(#{uid})"/>'
    # Veins: from where the stalk joins to the five lobe tips.
    root_a = math.radians(-90 + rot)
    rx, ry = cx + math.cos(root_a) * size * 0.14, cy + math.sin(root_a) * size * 0.14
    vein = c["vein"] if kind == "next" else c["leaf_light"]
    for phi, k in ((0, 0.84), (64, 0.8), (-64, 0.8), (124, 0.7), (-124, 0.7)):
        a = math.radians(phi + 90 + rot)
        tx, ty = cx + math.cos(a) * size / 2.2 * _leaf_r(phi) * k, cy + math.sin(a) * size / 2.2 * _leaf_r(phi) * k
        mx, my = (rx + tx) / 2 + (ty - ry) * 0.06, (ry + ty) / 2 - (tx - rx) * 0.06
        out += (f'<path d="M{_f(rx, ry)} Q{_f(mx, my)} {_f(tx, ty)}" stroke="{vein}" stroke-width="{size * 0.032:.2f}" '
                f'fill="none" stroke-linecap="round" opacity="{0.85 if kind == "next" else 0.6}"/>')
    return out


# ---------------------------------------------------------------------------------------
# The grape bunch (a lesson done)

BUNCH = [(-0.36, -0.34), (-0.12, -0.38), (0.12, -0.38), (0.36, -0.34),
         (-0.24, -0.12), (0.0, -0.14), (0.24, -0.12),
         (-0.13, 0.10), (0.13, 0.10), (0.0, 0.31)]


def bunch_svg(cx, cy, size, c, uid="g", tilt=0.0):
    """A ripe bunch of ten grapes, `size` points tall, a little leaf and stalk on top."""
    s = size
    r = s * 0.15
    t = math.radians(tilt)
    out = (f'<defs><radialGradient id="{uid}" cx="0.35" cy="0.3" r="0.75"><stop offset="0" stop-color="{c["grape_light"]}"/>'
           f'<stop offset="0.5" stop-color="{c["grape"]}"/><stop offset="1" stop-color="{c["grape_deep"]}"/></radialGradient></defs>')
    # Stalk and a small leaf sitting on the bunch's shoulder.
    out += (f'<path d="M{_f(cx, cy - s * 0.42)} Q{_f(cx + s * 0.02, cy - s * 0.55)} {_f(cx - s * 0.04, cy - s * 0.62)}" '
            f'stroke="{c["wood"]}" stroke-width="{s * 0.06:.2f}" fill="none" stroke-linecap="round"/>')
    out += leaf_svg(cx + s * 0.27, cy - s * 0.47, s * 0.42, c, "open", rot=-35, uid=uid + "l")
    for (x, y) in sorted(BUNCH, key=lambda q: -q[1]):
        x, y = x * math.cos(t) - y * math.sin(t), x * math.sin(t) + y * math.cos(t)
        gx, gy = cx + x * s, cy + y * s
        out += f'<circle cx="{gx:.2f}" cy="{gy:.2f}" r="{r:.2f}" fill="url(#{uid})" stroke="{c["grape_deep"]}" stroke-width="{s * 0.012:.2f}"/>'
        out += f'<circle cx="{gx - r * 0.35:.2f}" cy="{gy - r * 0.38:.2f}" r="{r * 0.22:.2f}" fill="{c["bloom"]}" opacity="0.75"/>'
    return out


# ---------------------------------------------------------------------------------------
# The bud (a lesson still locked)

def bud_svg(cx, cy, size, c):
    """A small closed bud, `size` points tall, pointing up and a little to the side."""
    s = size
    body = smooth_d([(cx, cy - s * 0.5), (cx + s * 0.3, cy - s * 0.05), (cx + s * 0.22, cy + s * 0.32),
                     (cx, cy + s * 0.42), (cx - s * 0.22, cy + s * 0.32), (cx - s * 0.3, cy - s * 0.05)])
    fold = (f'M{_f(cx, cy - s * 0.5)} Q{_f(cx - s * 0.08, cy)} {_f(cx - s * 0.02, cy + s * 0.4)}')
    return (f'<path d="{body}" fill="{c["bud"]}" stroke="{c["bud_deep"]}" stroke-width="{s * 0.06:.2f}"/>'
            f'<path d="{fold}" stroke="{c["bud_deep"]}" stroke-width="{s * 0.06:.2f}" fill="none" stroke-linecap="round"/>')


# ---------------------------------------------------------------------------------------
# Tendrils, the stem and the trellis bar

def tendril_d(x, y, size, side=-1, turns=1.6):
    """A tendril: a short reach out to one side ending in a curl."""
    reach = size * 0.55
    ex, ey = x + side * reach, y - size * 0.25
    pts = [(x + side * reach * t, y - size * 0.25 * t - math.sin(t * math.pi) * size * 0.12)
           for t in (i / 7 for i in range(8))]
    # The curl: a shrinking circle whose centre sits above the reach's end.
    r0 = size * 0.24
    for i in range(1, 30):
        t = i / 29
        a = math.pi / 2 - side * t * turns * 2 * math.pi
        r = r0 * (1 - 0.75 * t)
        pts.append((ex + side * r * math.cos(a), ey - r0 + r * math.sin(a)))
    return "M" + " L".join(_f(*p) for p in pts)


def _sample(pts, per=12):
    """Points along the smooth curve through pts (Catmull-Rom), `per` to a piece."""
    out, n = [], len(pts) - 1
    for i in range(n):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(n, i + 2)]
        for j in range(per):
            t = j / per
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    out.append(pts[-1])
    return out


def stem_d(pts, w0, w1):
    """The stem through pts (bottom to top) as one filled shape, w0 wide at the bottom
    tapering to w1 at the top."""
    s = _sample(pts)
    left, right = [], []
    for i, p in enumerate(s):
        q0, q1 = s[max(0, i - 1)], s[min(len(s) - 1, i + 1)]
        dx, dy = q1[0] - q0[0], q1[1] - q0[1]
        ln = math.hypot(dx, dy) or 1
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / (len(s) - 1)) / 2
        left.append((p[0] + nx * w, p[1] + ny * w))
        right.append((p[0] - nx * w, p[1] - ny * w))
    d = "M" + " L".join(_f(*q) for q in left)
    d += " L" + " L".join(_f(*q) for q in reversed(right)) + "Z"
    return d


def stem_svg(pts, w0, w1, colour, deep, light=None):
    """The stem: a darker edge, the wood, and a thin light streak along it."""
    out = f'<path d="{stem_d(pts, w0 + 2.4, w1 + 2.4)}" fill="{deep}" stroke="{deep}" stroke-width="1" stroke-linejoin="round"/>'
    out += f'<path d="{stem_d(pts, w0, w1)}" fill="{colour}"/>'
    if light:
        shifted = [(x - w0 * 0.18, y) for x, y in pts]
        out += f'<path d="{stem_d(shifted, w0 * 0.22, w1 * 0.22)}" fill="{light}" opacity="0.55"/>'
    return out


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


def perch_svg(stem_x, y, c, R=13.5, pose="hello", reach=46):
    """Ara perched on a short branch to the left of the stem at height y, facing the leaf:
    the parrot, then the branch over its tail, then its toes gripping the branch."""
    o = ara.POSES[pose]
    a = math.radians(o["lean"])
    fx, fy = 0.15, 2.98                               # between the feet, in the body's unit space
    foot = (fx * math.cos(a) - fy * math.sin(a), fx * math.sin(a) + fy * math.cos(a))
    perch_x = stem_x - reach * 0.6
    cx, cy = perch_x - foot[0] * R, y - foot[1] * R
    x_to = stem_x - reach
    mid = (stem_x + x_to) / 2
    d = f"M{_f(stem_x, y - 7)} Q{_f(mid, y + 1)} {_f(x_to, y + 1)}"
    out = ara.mascot_svg(cx, cy, R, pose)
    out += (f'<path d="{d}" stroke="{c["wood_deep"]}" stroke-width="6.6" fill="none" stroke-linecap="round"/>'
            f'<path d="{d}" stroke="{c["wood"]}" stroke-width="5" fill="none" stroke-linecap="round"/>')
    for dx in (-0.36 * R, 0.2 * R):                   # toes over the branch
        out += f'<ellipse cx="{perch_x + dx:.2f}" cy="{y - 0.5:.2f}" rx="{R * 0.17:.2f}" ry="{R * 0.22:.2f}" fill="{ara.FOOT}"/>'
    return out
