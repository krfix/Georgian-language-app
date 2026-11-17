"""The Ara identity as geometry: the symbol (Ara's head) and the mascot (the whole parrot).

Everything is built from circles, arcs and a few smooth curves in a unit space where Ara's
head is a circle of radius 1 at (0, 0), facing right. One set of numbers draws the app icon,
the logo, the launch mark and every mascot pose, so they always match. See docs/brand.md.

The symbol: a round head whose hooked macaw beak is also the tail of a speech bubble (Ara
speaks), one bright eye, and a short gold-and-blue curl of neck feathers under the chin
(the colours of a scarlet macaw's wing, and the start of the mascot's body).
"""
import math

# Colours (HEX). The first five are the app's brand colours (DesignSystem/Palette.swift).
POMEGRANATE = "#E23B4E"   # Ara's red
SAPERAVI = "#7A3BC2"      # wine purple
GOLD = "#F5B731"          # church-enamel gold (the wing band)
TKEMALI = "#2FA45A"       # plum green
BLACKSEA = "#1592AD"      # turquoise
MACAW = "#1E5FC8"         # deep blue: the flight feathers (supporting colour)
MACAW_DEEP = "#16449C"    # the blue band on the icon's turquoise-to-purple background
RED_DEEP = "#C42D46"      # the far tail feather
HORN = "#F7DDAE"          # the beak
INK = "#24182A"           # text and the pupil
PAPER = "#FFF7EF"         # light background, and the white of the eye
NIGHT = "#120E18"         # dark background
NIGHT_RAISED = "#2B1B3D"
FOOT = "#4A3A4E"
BEAK_SHADE = "#2A1A2E"    # the lower beak


def _pt(a, r=1.0, c=(0.0, 0.0)):
    return (c[0] + r * math.cos(math.radians(a)), c[1] + r * math.sin(math.radians(a)))


class Space:
    """Maps unit space to a canvas: head centre (cx, cy), head radius R, turned by rot degrees."""

    def __init__(self, cx, cy, R, rot=0.0):
        self.cx, self.cy, self.R, self.rot = cx, cy, R, rot

    def p(self, q):
        c, s = math.cos(math.radians(self.rot)), math.sin(math.radians(self.rot))
        x, y = q
        return (self.cx + self.R * (x * c - y * s), self.cy + self.R * (x * s + y * c))

    def f(self, q):
        x, y = self.p(q)
        return f"{x:.2f},{y:.2f}"

    def r(self, v):
        return f"{v * self.R:.2f}"


def circle(sp, c, r, fill):
    x, y = sp.p(c)
    return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r * sp.R:.2f}" fill="{fill}"/>'


def circle_d(sp, c, r, clockwise=True):
    """A circle as path data (for one-colour shapes with holes)."""
    x, y = sp.p(c)
    R = r * sp.R
    sweep = 1 if clockwise else 0
    return f"M{x - R:.2f},{y:.2f} A{R:.2f},{R:.2f} 0 1 {sweep} {x + R:.2f},{y:.2f} A{R:.2f},{R:.2f} 0 1 {sweep} {x - R:.2f},{y:.2f}Z"


# ---------------------------------------------------------------------------------------
# The head (the symbol)

HEAD_TILT = -8            # degrees: chin slightly up, curious
BEAK_START = -62          # where the beak leaves the head (angle on the head circle)
BEAK_END = 28             # where its inner curve meets the head again
BEAK_OUTER = 1.09         # radius of the beak's outer curve
BEAK_INNER = 0.60         # radius of the hook's inner curve
BEAK_TIP = (0.98, 1.20)   # the hook's point, pointing down like a speech bubble's tail
LOWER = ((1.00, 0.60), 0.17)      # the dark lower beak, tucked under the hook
EYE = ((0.38, -0.22), 0.27)       # white of the eye
PUPIL = 0.50                      # pupil radius, as a share of the eye's
COLLAR = ((GOLD, 1.0, 1.20), (MACAW, 1.20, 1.38))   # neck feathers: colour, inner, outer radius
COLLAR_FROM, COLLAR_TO = 100, 160                    # degrees round the head (below-left)


def beak_d(sp, gap=0.0):
    """The upper beak: outer curve to the tip, inner curve back, then along the head's edge,
    so it sits exactly outside the head (with an optional gap for one-colour versions)."""
    hr = 1.0 + gap
    S, E = _pt(BEAK_START, hr), _pt(BEAK_END, hr)
    return (f"M{sp.f(S)} A{sp.r(BEAK_OUTER)},{sp.r(BEAK_OUTER)} 0 0 1 {sp.f(BEAK_TIP)} "
            f"A{sp.r(BEAK_INNER)},{sp.r(BEAK_INNER)} 0 0 0 {sp.f(E)} "
            f"A{sp.r(hr)},{sp.r(hr)} 0 0 0 {sp.f(S)}Z")


def band_d(sp, r0, r1, a0, a1, c=(0.0, 0.0)):
    """An arc band with round ends, from angle a0 to a1 between radii r0 and r1."""
    w = (r1 - r0) / 2
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return (f"M{sp.f(_pt(a0, r1, c))} A{sp.r(r1)},{sp.r(r1)} 0 {large} 1 {sp.f(_pt(a1, r1, c))} "
            f"A{sp.r(w)},{sp.r(w)} 0 0 1 {sp.f(_pt(a1, r0, c))} "
            f"A{sp.r(r0)},{sp.r(r0)} 0 {large} 0 {sp.f(_pt(a0, r0, c))} "
            f"A{sp.r(w)},{sp.r(w)} 0 0 1 {sp.f(_pt(a0, r1, c))}Z")


def eye_svg(sp, mood="open", look=(0.2, 0.0), white=PAPER, ink=INK):
    (ex, ey), er = EYE
    out = circle(sp, (ex, ey), er, white)
    x, y = sp.p((ex, ey))
    R = er * sp.R
    if mood == "open":
        pr = er * PUPIL
        px, py = ex + er * look[0], ey + er * look[1]
        out += circle(sp, (px, py), pr, ink)
        out += circle(sp, (px + pr * 0.35, py - pr * 0.4), pr * 0.32, "#FFFFFF")
    elif mood == "happy":      # a smiling arc
        out += (f'<path d="M{x - R * 0.55:.2f},{y + R * 0.18:.2f} Q{x:.2f},{y - R * 0.62:.2f} {x + R * 0.55:.2f},{y + R * 0.18:.2f}" '
                f'stroke="{ink}" stroke-width="{R * 0.30:.2f}" fill="none" stroke-linecap="round"/>')
    else:                      # closed (blinking, sleeping)
        out += (f'<path d="M{x - R * 0.55:.2f},{y - R * 0.05:.2f} Q{x:.2f},{y + R * 0.50:.2f} {x + R * 0.55:.2f},{y - R * 0.05:.2f}" '
                f'stroke="{ink}" stroke-width="{R * 0.28:.2f}" fill="none" stroke-linecap="round"/>')
    return out


def head_svg(sp, beak=HORN, collar=True, collar_colors=None, mood="open", look=(0.2, 0.0), head=POMEGRANATE):
    out = ""
    if collar:
        cols = collar_colors or [c for c, _, _ in COLLAR]
        for (c, r0, r1), col in zip(COLLAR, cols):
            out += f'<path d="{band_d(sp, r0, r1, COLLAR_FROM, COLLAR_TO)}" fill="{col}"/>'
    out += circle(sp, *LOWER, BEAK_SHADE)
    out += circle(sp, (0, 0), 1, head)
    out += f'<path d="{beak_d(sp)}" fill="{beak}"/>'
    out += eye_svg(sp, mood, look)
    return out


def symbol_mono_d(sp):
    """The symbol in one colour as a single even-odd path: the eye is a hole with the pupil
    and its light inside it. The beak stays joined to the head (the speech-bubble outline);
    small gaps keep the collar's bands apart."""
    (ex, ey), er = EYE
    pr = er * PUPIL
    px, py = ex + er * 0.2, ey
    parts = [circle_d(sp, (0, 0), 1), circle_d(sp, (ex, ey), er), circle_d(sp, (px, py), pr),
             circle_d(sp, (px + pr * 0.35, py - pr * 0.4), pr * 0.32)]
    g = 0.07
    parts.append(band_d(sp, 1.0 + g, 1.20 + g * 0.5, COLLAR_FROM, COLLAR_TO))
    parts.append(band_d(sp, 1.20 + g * 1.5, 1.38 + g * 1.5, COLLAR_FROM, COLLAR_TO))
    # The beak is a second shape reaching a little into the head: one outline, no seam.
    return " ".join(parts), beak_d(sp, gap=-0.02)


# The symbol's ink box in unit space (head, beak, collar), turned by HEAD_TILT; measured by
# make_brand.py and used to centre the symbol optically.
SYMBOL_BOX = None


# ---------------------------------------------------------------------------------------
# The mascot: the same head on a scarlet-macaw body

def _rot(q, piv, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y = q[0] - piv[0], q[1] - piv[1]
    return (piv[0] + x * c - y * s, piv[1] + x * s + y * c)


def _path(sp, start, curves, fill):
    d = "M" + sp.f(start) + " " + " ".join("C" + " ".join(sp.f(q) for q in c) for c in curves) + "Z"
    return f'<path d="{d}" fill="{fill}"/>'


def _feather(sp, root, ang, length, width, fill, bend=0.0):
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx

    def q(t, w, b=0.0):
        return (root[0] + dx * length * t + nx * (w + b), root[1] + dy * length * t + ny * (w + b))
    tip = q(1, 0, bend)
    return _path(sp, q(0, width), [(q(0.35, width * 1.05), q(0.75, width * 0.7, bend * 0.6), tip),
                                   (q(0.75, -width * 0.7, bend * 0.6), q(0.35, -width * 1.05), q(0, -width)),
                                   (q(-0.25, -width * 1.1), q(-0.25, width * 1.1), q(0, width))], fill)


def _wing(sp, raised=False):
    """A folded macaw wing: red shoulder, gold band, blue flight feathers. Raised, it waves."""
    piv = (-0.5, 1.1)

    def layer(tip, fill, k):
        def t(a, b):
            return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
        sh = (0.42, 1.05)
        pts = [sh, (0.72, 1.55), t((0.72, 1.55), (0.25, 2.45)), tip, t((-0.7, 1.5), (-0.78, 2.5)),
               (-0.7, 1.4), (-0.42, 0.95), (-0.15, 0.78), (0.22, 0.82), sh]
        if raised:
            pts = [_rot(p, piv, 110) for p in pts]
        return _path(sp, pts[0], [pts[1:4], pts[4:7], pts[7:10]], fill)
    return layer((-0.62, 3.05), MACAW, 1.0) + layer((-0.38, 2.35), GOLD, 0.68) + layer((-0.12, 1.72), POMEGRANATE, 0.35)


# Poses: body lean (degrees), head tilt, eye, where the pupil looks, wing raised.
POSES = {
    "hello": dict(lean=12, tilt=-8, mood="open", look=(0.2, 0.0), raised=False),
    "blink": dict(lean=12, tilt=-8, mood="closed", look=(0.2, 0.0), raised=False),
    "cheer": dict(lean=6, tilt=-18, mood="happy", look=(0.2, 0.0), raised=True),
    "think": dict(lean=10, tilt=-24, mood="open", look=(0.25, -0.32), raised=False),
    "sleep": dict(lean=14, tilt=8, mood="closed", look=(0.2, 0.0), raised=False),
}


def mascot_svg(cx, cy, R, pose="hello"):
    o = POSES[pose]
    body = Space(cx, cy, R, o["lean"])
    head = Space(cx, cy, R, o["tilt"])
    out = _feather(body, (-0.42, 2.7), 104, 1.9, 0.26, MACAW_DEEP)          # tail, behind
    out += _feather(body, (-0.22, 2.72), 96, 2.1, 0.27, RED_DEEP)
    out += _path(body, (0.62, 0.78), [((1.15, 1.35), (1.05, 2.35), (0.35, 2.8)),
                                      ((0.0, 3.0), (-0.5, 2.95), (-0.72, 2.7)),
                                      ((-1.12, 2.15), (-1.1, 1.0), (-0.86, 0.5))], POMEGRANATE)
    for x in (-0.12, 0.42):                                                   # feet
        out += _path(body, (x - 0.24, 2.92), [((x - 0.2, 3.12), (x + 0.2, 3.12), (x + 0.24, 2.92)),
                                              ((x + 0.1, 2.84), (x - 0.1, 2.84), (x - 0.24, 2.92))], FOOT)
    out += _wing(body, o["raised"])
    out += head_svg(head, collar=False, mood=o["mood"], look=o["look"])
    return out
