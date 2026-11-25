"""Still mock-ups of the grapevine Learn path (docs/vine-path.md), drawn from vine.py.

Called by make_brand.py --vine. These are pictures to decide on, not app assets: the
screen is an iPhone's 402 x 874 points, the text is the real course (course.json), and the
tab bar is simplified. Nothing here ships in the app.
"""
import json
import math
import os

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

import ara
import vine

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
W, H = 402, 874

FONTS = {}


def _font(name):
    if name not in FONTS:
        f = TTFont(os.path.join(HERE, "fonts", name))
        FONTS[name] = (f, f.getGlyphSet(), f.getBestCmap(), f["hmtx"], f["head"].unitsPerEm)
    return FONTS[name]


def _pick(ch, weight):
    if 0x10A0 <= ord(ch) <= 0x10FF:
        return "NotoSansGeorgian-Bold.ttf" if weight != "regular" else "NotoSansGeorgian-Regular.ttf"
    return {"black": "Nunito-Black.ttf"}.get(weight, "Nunito-Bold.woff2")


def text_d(s, x, baseline, size, weight="bold"):
    """Outlines of s at font size `size` (points), Nunito for Latin, Noto Sans Georgian for
    Georgian. Returns path data and width."""
    d, start = [], x
    for ch in s:
        f, gs, cmap, hm, upm = _font(_pick(ch, weight))
        g = cmap.get(ord(ch)) or cmap[32]
        sc = size / upm
        if ch != " ":
            p = SVGPathPen(gs)
            gs[g].draw(TransformPen(p, (sc, 0, 0, -sc, x, baseline)))
            d.append(p.getCommands())
        x += hm[g][0] * sc
    return " ".join(d), x - start


def width(s, size, weight="bold"):
    return text_d(s, 0, 0, size, weight)[1]


def fit(s, size, maxw, weight="bold"):
    if width(s, size, weight) <= maxw:
        return s
    while s and width(s + "…", size, weight) > maxw:
        s = s[:-1]
    return s.rstrip(" ·") + "…"


def wrap(s, size, maxw, weight="bold"):
    lines, line = [], ""
    for w in s.split():
        t = (line + " " + w).strip()
        if width(t, size, weight) > maxw and line:
            lines.append(line)
            line = w
        else:
            line = t
    return lines + [line]


def text(s, x, baseline, size, fill, weight="bold", anchor="start", opacity=1.0):
    d, w = text_d(s, 0, 0, size, weight)
    dx = {"start": 0, "middle": -w / 2, "end": -w}[anchor]
    d, _ = text_d(s, x + dx, baseline, size, weight)
    op = f' opacity="{opacity}"' if opacity < 1 else ""
    return f'<path d="{d}" fill="{fill}"{op}/>'


# ---------------------------------------------------------------------------------------

CARD = {  # module colour, its partner (the card's gradient, as BrandColor.partner)
    "pomegranate": ("#E23B4E", "#7A3BC2"), "saperavi": ("#7A3BC2", "#1592AD"),
    "gold": ("#F5A623", "#FF8A1F"), "blacksea": ("#1592AD", "#27964F"), "tkemali": ("#27964F", "#1592AD"),
}


def course():
    with open(os.path.join(ROOT, "Georgian", "Resources", "Curriculum", "course.json")) as f:
        return json.load(f)["modules"]


def card_height(m, w=W - 40):
    return module_card(m, 0, 0, w, 0, None, None)[1]


def module_card(m, x, y, w, done, c, theme):
    """The module's card (as today's, in its colour), with its top at y. Returns svg, height."""
    col, partner = CARD[m["color"]]
    on = "#2A1A06" if m["color"] == "gold" else "#FFFFFF"
    pad = 18
    intro = wrap(m["intro"], 13.5, w - 2 * pad)
    h = pad + 24 + 20 + len(intro) * 18 + 30 + pad - 6
    uid = "card" + m["id"]
    out = (f'<defs><linearGradient id="{uid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{col}"/>'
           f'<stop offset="1" stop-color="{partner}"/></linearGradient></defs>'
           f'<rect x="{x}" y="{y + 4}" width="{w}" height="{h}" rx="24" fill="{col}" opacity="0.35"/>'
           f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24" fill="url(#{uid})"/>')
    ty = y + pad + 20
    out += text(m["title"], x + pad, ty, 22, on, "black")
    out += text(m["subtitle"], x + pad, ty + 21, 14.5, on, opacity=0.85)
    for i, line in enumerate(intro):
        out += text(line, x + pad, ty + 44 + i * 18, 13.5, on, opacity=0.9)
    by = ty + 44 + len(intro) * 18 + 4
    n = len(m["lessons"])
    bw = w - 2 * pad - 46
    out += (f'<rect x="{x + pad}" y="{by}" width="{bw}" height="10" rx="5" fill="{on}" opacity="0.25"/>'
            f'<rect x="{x + pad}" y="{by}" width="{max(10, bw * done / n):.1f}" height="10" rx="5" fill="{on}" opacity="0.9"/>')
    out += text(f"{done}/{n}", x + w - pad, by + 9.5, 13, on, "black", anchor="end")
    return out, h


def status_bar(c, theme):
    ink = c["ink"]
    out = text("9:41", 50, 33, 17, ink, "black")
    out += f'<rect x="{W / 2 - 62}" y="11" width="124" height="36" rx="18" fill="#000"/>'
    for i, hh in enumerate((5, 7.5, 10, 12.5)):
        out += f'<rect x="{298 + i * 5.5}" y="{33 - hh}" width="3.6" height="{hh}" rx="1" fill="{ink}"/>'
    out += (f'<rect x="{330}" y="22" width="25" height="12" rx="3.5" fill="none" stroke="{ink}" stroke-width="1.2" opacity="0.5"/>'
            f'<rect x="{332}" y="24" width="18" height="8" rx="2" fill="{ink}"/>')
    return out


def nav(c, theme, title="Learn"):
    top = c["bg_top"]
    return (f'<defs><linearGradient id="navfade" x1="0" y1="0" x2="0" y2="1"><stop offset="0.82" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{top}" stop-opacity="0"/></linearGradient></defs>'
            f'<rect width="{W}" height="134" fill="url(#navfade)"/>' + status_bar(c, theme)
            + text(title, W / 2, 96, 17, c["ink"], "black", anchor="middle"))


def tab_bar(c, theme, active=1):
    """A simplified tab bar: the five tabs' names on the floating bar (no icons)."""
    bar = "#FFFFFF" if theme == "light" else "#2B1B3D"
    y = 790
    out = (f'<rect x="20" y="{y + 3}" width="{W - 40}" height="62" rx="31" fill="#000" opacity="0.08"/>'
           f'<rect x="20" y="{y}" width="{W - 40}" height="62" rx="31" fill="{bar}" opacity="0.96"/>')
    names = ["Home", "Learn", "Phrasebook", "Words", "Review"]
    xs = [62, 128, 201, 274, 340]
    for i, (n, x) in enumerate(zip(names, xs)):
        colr = "#E23B4E" if i == active else c["ink"]
        if i == active:
            out += f'<rect x="{x - 34}" y="{y + 6}" width="68" height="50" rx="25" fill="{c["ink"]}" opacity="0.06"/>'
        out += f'<circle cx="{x}" cy="{y + 24}" r="8" fill="{colr}" opacity="{1 if i == active else 0.75}"/>'
        out += text(n, x, y + 48, 11.5, colr, anchor="middle")
    return out


def background(c, theme):
    glow = "#7A3BC2" if theme == "light" else "#B07CF0"
    return (f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c["bg_top"]}"/>'
            f'<stop offset="1" stop-color="{c["bg_bottom"]}"/></linearGradient>'
            f'<radialGradient id="amb" cx="0.85" cy="0.1" r="0.7"><stop offset="0" stop-color="{glow}" stop-opacity="0.10"/>'
            f'<stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient></defs>'
            f'<rect width="{W}" height="{H}" fill="url(#bg)"/><rect width="{W}" height="{H}" fill="url(#amb)"/>')


# ---------------------------------------------------------------------------------------
# The vine itself

ROW = 92           # points between lessons
STEM_X = 100       # the stem's middle; it sways STEM_SWAY either side
STEM_SWAY = 18
ITEM_DX = 46       # from the stem to a lesson's picture
TEXT_X = 210       # titles start here
BAR_H = 14


def stem_x(k):
    return STEM_X + STEM_SWAY * math.sin(k * 1.3 + 0.4)


class Vine:
    """How thick and how woody the vine is at any height (world y, growing upward from the
    first lesson), for a learner whose next lesson is at world y `nxt`. Woodiness: brown old
    bark well below the next lesson, cane and yellow straw over the last lessons done, green
    from the next lesson up (cane ripening runs from the base to the tip)."""

    def __init__(self, nxt, total):
        self.nxt, self.total = nxt, total

    def wood(self, wy):
        dn = self.nxt - wy
        return max(0.0, min(1.0, 0.22 + dn / 300)) if dn >= 0 else max(0.0, 0.22 + dn / 160)

    def width(self, wy):
        age = 1 - max(0.0, min(1.0, wy / self.total))
        return (6 + 16 * age ** 1.3) * (0.7 + 0.3 * vine.smoothstep(0, 0.6, self.wood(wy)))


def lesson_text(lesson, state, y, c):
    title_col = c["faint"] if state == "locked" else c["ink"]
    out = text(fit(lesson["title"], 17, W - TEXT_X - 16), TEXT_X, y - 1, 17, title_col, "black")
    out += text(fit(lesson["subtitle"], 12.5, W - TEXT_X - 16, "regular"), TEXT_X, y + 17, 12.5,
                c["faint"] if state == "locked" else c["soft"], "regular")
    return out


def vine_scene(rows, sy, vn, c, top_cut=None, above=()):
    """The vine through the rows on screen: the stem (zig-zagging a little at each node, as a
    real shoot does), then at every lesson a node with its picture on the right and, opposite
    it, a leaf (or Ara's perch); between lessons a node with a leaf and a forked tendril.
    rows: (kind, module, lesson, state, world y, ripeness), bottom to top; sy: world y to
    screen y. Returns (under, over): the stem and its growths, and the lesson pictures."""
    pts, nodes = [], []
    for k, r in enumerate(rows):
        x, y = stem_x(r[6]), sy(r[4])
        if r[0] == "card":
            pts.append((x, y + 30))
            continue
        kink = 3 if r[6] % 2 else -3
        pts.append((x + kink, y - 16))                            # the node
        nodes.append(("lesson", r, x + kink, y - 16))
        if k + 1 < len(rows) and rows[k + 1][0] == "lesson":
            nx = stem_x(r[6] + 1)
            mx, my = (x + nx) / 2 - kink, y - 16 - ROW / 2
            pts.append((mx, my))
            nodes.append(("between", r, mx, my))
    if top_cut is not None:
        pts.append((pts[-1][0] + 4, top_cut))
    pts += list(above)              # where the stem goes on above the last lesson
    # Down off the bottom of the screen, in even steps (uneven ones make the curve overshoot).
    below, yb = [], pts[0][1] + ROW / 2
    while yb < H + 260:
        below.insert(0, (pts[0][0] - 3 * math.sin(yb / 70), yb))
        yb += ROW / 2
    pts = below + pts
    wy = lambda p: sy(0) - p[1]   # noqa: E731  (screen y back to world y)
    under = vine.stem_svg(pts, lambda p: vn.width(wy(p)), lambda p: vn.wood(wy(p)), c, seed=7)
    over = ""
    growths = ""
    for kind, r, x, y in nodes:
        m = vn.wood(wy((x, y)))
        w = vn.width(wy((x, y)))
        k = r[6]
        seed = k * 13 + (1 if kind == "between" else 0)
        if kind == "lesson":
            state = r[3]
            ix, iy = x + ITEM_DX - (5 if k % 2 else -5), sy(r[4])
            if state == "locked":
                growths += vine.stalk_svg(x + 2, y + 2, x + 16, y - 4, c, m, bend=-0.2, w=2.2)
                over += vine.bud_svg(x + 20, y - 9, 20, c)
                # A young bronze leaf unfolding opposite.
                growths += vine.stalk_svg(x - 2, y, x - 18, y - 10, c, m, bend=0.25, w=2)
                growths += vine.leaf_svg(x - 24, y - 4, 20 + (k % 3) * 3, c, "young", rot=50, uid=f"y{k}", sh=vine.leaf_shape(seed))
            else:
                growths += vine.stalk_svg(x + 2, y, ix - 2, iy - 32, c, m, bend=-0.25, w=3)
                if state == "done":
                    over += vine.bunch_svg(ix, iy + 4, 62, c, uid=f"g{k}", ripe=r[5], seed=seed, tilt=4 if k % 2 else -4)
                else:
                    over += vine.leaf_svg(ix, iy + 2, 66 if state == "next" else 56, c, state, rot=6 if k % 2 else -6, uid=f"l{k}")
                if state == "next":
                    over += vine.perch_svg(x - 3, iy + 22, c, R=14, reach=54, m=m)
                else:
                    # The leaf opposite the bunch, on its own stalk, out to the left.
                    lx, ly = x - 30 - (k % 3) * 4, y - 4 + (k % 2) * 6
                    growths += vine.stalk_svg(x - 2, y, lx + 6, ly - 12, c, m * 0.6, bend=0.3, w=2.4)
                    growths += vine.leaf_svg(lx, ly, 38 + (k % 4) * 4, c, "deco", rot=30 + (k % 3) * 12, uid=f"o{k}",
                                             sh=vine.leaf_shape(seed), colour=c["deco"][k % 4])
            growths += vine.node_svg(x, y, w, -8 if k % 2 else 8, c, m)
        else:
            # Between lessons: two nodes in three carry a tendril (here on the right, reaching
            # into the gap), and every node a leaf (here on the left).
            col = vine.mix(c["shoot"], c["cane"], vine.smoothstep(0.4, 0.9, m))
            if k % 3 != 2:
                growths += vine.tendril_svg(x + 2, y, 44 + (k % 2) * 8, -30 + (k % 3) * 22, c, seed=seed, colour=col,
                                            spring=(k % 4 == 1), w=2.2)
            if k % 3 == 2:
                # The node without a tendril on the right: one reaches out to the left instead.
                growths += vine.tendril_svg(x - 4, y - 6, 50, 200 + (k % 2) * 25, c, seed=seed + 50, colour=col, w=2.2)
            lx, ly = x - 34 - (k % 2) * 6, y + 8
            young = vn.wood(wy((x, y))) == 0 and wy((x, y)) > vn.nxt + ROW * 1.5
            growths += vine.stalk_svg(x - 2, y, lx + 5, ly - 12, c, m * 0.6, bend=0.35, w=2.2)
            growths += vine.leaf_svg(lx, ly, (24 if young else 30) + (k % 3) * 5, c, "young" if young else "deco",
                                     rot=40 + (k % 2) * 15, uid=f"b{k}", sh=vine.leaf_shape(seed),
                                     colour=c["deco"][(k + 2) % 4])
            growths += vine.node_svg(x, y, w, 6, c, m)
    return under + growths, over


def ripeness(order_from_next):
    """For the mock-ups: the lesson just finished is green, the one before blushing, older
    ones ripe. (In the app it could follow how well their words are remembered instead.)"""
    return {1: "green", 2: "blush"}.get(order_from_next, "purple")


def learn_screen(theme, upto=("vocabulary", 3)):
    """The Learn screen with the vine: all of the first module and `upto` lessons of the
    named module done; the next lesson a little above the middle, with Ara beside it."""
    c = vine.VINE_COLOURS[theme]
    mods = course()
    rows, y, finished, k = [], 0.0, True, 0
    for m in mods:
        y += card_height(m) + 40
        rows.append(["card", m, None, None, y, None, k])
        y += 76
        for i, l in enumerate(m["lessons"]):
            if m["id"] == upto[0]:
                state = "done" if i < upto[1] else ("next" if i == upto[1] else "locked")
            else:
                state = "done" if finished else "locked"
            rows.append(["lesson", m, l, state, y, None, k])
            y += ROW
            k += 1
        y += 10
        if m["id"] == upto[0]:
            finished = False
    total = y
    lessons = [r for r in rows if r[0] == "lesson"]
    ni = next(i for i, r in enumerate(lessons) if r[3] == "next")
    for i, r in enumerate(lessons[:ni]):
        r[5] = ripeness(ni - i)
    nxt = lessons[ni][4]
    shift = 340 + nxt                # the next lesson sits at screen y 340
    sy = lambda wy: shift - wy       # noqa: E731
    vn = Vine(nxt, total)
    vis = [r for r in rows if -160 < sy(r[4]) < H + 200]

    body = background(c, theme)
    under, over = vine_scene(vis, sy, vn, c)
    body += under
    for r in vis:
        if r[0] != "card":
            continue
        m = r[1]
        y0 = sy(r[4])
        done = sum(1 for q in rows if q[0] == "lesson" and q[1] is m and q[3] == "done")
        card, ch = module_card(m, 20, y0 + 30, W - 40, done, c, theme)
        ropes = "".join(f'<path d="M{x},{y0 + 8} L{x},{y0 + 32}" stroke="{c["rope"]}" stroke-width="2.4" stroke-linecap="round"/>'
                        f'<circle cx="{x}" cy="{y0 + 8}" r="3.6" fill="{c["rope"]}"/>' for x in (56, W - 56))
        body += ropes + vine.trellis_svg(-12, W + 12, y0, c, BAR_H)
        sx = stem_x(r[6])
        mm = vn.wood(r[4])
        body += vine.coil_round_bar(sx + 14, y0, BAR_H, vine.mix(c["shoot"], c["cane"], mm), turns=3)
        body += vine.coil_round_bar(sx - 36, y0, BAR_H, vine.mix(c["shoot"], c["cane"], mm), turns=2)
        body += card
    body += over
    for r in vis:
        if r[0] == "lesson":
            body += lesson_text(r[2], r[3], sy(r[4]), c)
    body += nav(c, theme) + tab_bar(c, theme)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>\n'


# ---------------------------------------------------------------------------------------
# The top of the vine: after the last module, a full vine over a supra table (Tamada)

def supra_table(cx, top, c, theme):
    """A long supra table with a white cloth, a clay jug, pomegranates, bread and khachapuri, and a
    place for Ara; `top` is the table top's y."""
    cloth = "#FFFDF8" if theme == "light" else "#EDE3D6"
    shade = "#E9DFD2" if theme == "light" else "#BFB2A4"
    x0, x1 = cx - 165, cx + 165
    out = ""
    for lx in (x0 + 30, x1 - 30):                                       # legs
        out += f'<rect x="{lx - 5}" y="{top + 30}" width="10" height="64" rx="4" fill="{c["wood_deep"]}"/>'
    # The cloth: the top, then the drop with a scalloped hem.
    hem = "".join(f" Q{x0 + 22 * i + 11:.1f},{top + 66:.1f} {x0 + 22 * (i + 1):.1f},{top + 58:.1f}" for i in range(15))
    out += f'<path d="M{x0},{top} L{x1},{top} L{x1},{top + 58} L{x0},{top + 58} Z" fill="{cloth}"/>'
    out += f'<path d="M{x0},{top + 58}{hem} L{x1},{top + 52} L{x0},{top + 52} Z" fill="{cloth}"/>'
    out += f'<rect x="{x0}" y="{top}" width="{x1 - x0}" height="10" fill="{shade}"/>'
    out += f'<rect x="{x0}" y="{top + 20}" width="{x1 - x0}" height="3" fill="#E23B4E" opacity="0.55"/>'
    # On the table (their bottoms sit on `top`).
    # A clay jug.
    jx = x0 + 42
    out += (f'<path d="M{jx - 16},{top} C{jx - 26},{top - 22} {jx - 16},{top - 40} {jx - 7},{top - 44} L{jx - 7},{top - 56} '
            f'L{jx + 7},{top - 56} L{jx + 7},{top - 44} C{jx + 16},{top - 40} {jx + 26},{top - 22} {jx + 16},{top} Z" fill="#B9653A"/>'
            f'<path d="M{jx + 9},{top - 48} C{jx + 26},{top - 50} {jx + 28},{top - 28} {jx + 17},{top - 22}" stroke="#B9653A" stroke-width="4" fill="none"/>'
            f'<rect x="{jx - 10}" y="{top - 60}" width="20" height="6" rx="3" fill="#9C4E2A"/>'
            f'<path d="M{jx - 14},{top - 24} Q{jx},{top - 18} {jx + 14},{top - 24}" stroke="#E8A270" stroke-width="2.2" fill="none"/>')
    # Shoti bread: a long canoe.
    bx = x0 + 157
    out += (f'<path d="M{bx - 32},{top - 2} Q{bx},{top - 26} {bx + 32},{top - 2} Q{bx},{top + 4} {bx - 32},{top - 2} Z" fill="#D9A45B"/>'
            f'<path d="M{bx - 20},{top - 9} Q{bx},{top - 20} {bx + 20},{top - 9}" stroke="#F2CB8A" stroke-width="2.5" fill="none" stroke-linecap="round"/>')
    # Khachapuri on a plate: a boat of bread, cheese and a yolk.
    kx = cx + 61
    out += f'<ellipse cx="{kx}" cy="{top - 2}" rx="38" ry="6" fill="{shade}"/>'
    out += (f'<path d="M{kx - 34},{top - 8} Q{kx},{top - 38} {kx + 34},{top - 8} Q{kx},{top + 2} {kx - 34},{top - 8} Z" fill="#D9A45B"/>'
            f'<ellipse cx="{kx}" cy="{top - 14}" rx="20" ry="7" fill="#FFE08A"/>'
            f'<circle cx="{kx}" cy="{top - 15}" r="5.5" fill="#F5A623"/>')
    # Two pomegranates.
    for px, r in ((x0 + 86, 11), (x0 + 106, 9)):
        out += (f'<circle cx="{px}" cy="{top - r}" r="{r}" fill="#E23B4E"/>'
                f'<path d="M{px - 3},{top - 2 * r} L{px},{top - 2 * r - 4} L{px + 3},{top - 2 * r}" fill="#A9213A"/>'
                f'<circle cx="{px - r * 0.35}" cy="{top - r * 1.35}" r="{r * 0.25}" fill="#FFFFFF" opacity="0.5"/>')
    return out



def canopy(y, c):
    """The full vine overhead: a pergola beam hidden in leaves of every shade and shape,
    ripe bunches (and one still green) hanging under it, tendrils and a growing tip."""
    out = vine.trellis_svg(-12, W + 12, y, c, BAR_H)
    back = [(-8, -4), (26, -18), (60, 2), (96, -14), (132, 4), (168, -16), (206, 0), (242, -16), (280, 4),
            (316, -12), (352, 2), (390, -14)]
    for i, (x, dy) in enumerate(back):
        out += vine.leaf_svg(x, y + dy - 6, 50 + (i % 3) * 6, c, "deco", rot=(i % 5 - 2) * 18, uid=f"cb{i}",
                             sh=vine.leaf_shape(100 + i), colour=c["deco"][i % 4])
    for i, x in enumerate((20, 96, 186, 262, 336)):
        out += vine.tendril_svg(x + 10, y + 18, 34, 70 + (i % 3) * 20, c, seed=200 + i, spring=i % 2 == 0)
    for i, (x, ripe) in enumerate(((46, "purple"), (132, "purple"), (222, "blush"), (300, "purple"), (374, "green"))):
        out += vine.stalk_svg(x - 4, y + 10, x, y + 36, c, 0.6, bend=0.2, w=2.6)
        out += vine.bunch_svg(x, y + 62 + (i % 2) * 12, 52 + (i % 3) * 4, c, uid=f"cg{i}", ripe=ripe, seed=300 + i,
                              tilt=(i % 3 - 1) * 6)
    front = back[1::2]
    for i, (x, dy) in enumerate(front):
        out += vine.leaf_svg(x + 16, y + dy + 22, 40 + (i % 2) * 8, c, "deco", rot=(i % 2) * 34 - 17, uid=f"cf{i}",
                             sh=vine.leaf_shape(400 + i), colour=c["deco"][(i + 1) % 4])
    out += vine.tip_svg(W - 50, y - 18, c, size=30, side=-1, uid="ctip")
    return out


def top_screen(theme):
    """The top of Learn once every lesson is done: the last lessons as grapes, then the full
    vine over a supra table, with Ara cheering on it: the Tamada stage."""
    c = vine.VINE_COLOURS[theme]
    m = course()[-1]
    body = background(c, theme)
    rows = []
    for j, l in enumerate(m["lessons"][-3:]):
        rows.append(["lesson", m, l, "done", -(574 + (2 - j) * ROW), "purple", 60 + j])
    # A finished vine: all ripe and woody, the stem climbing on up the left to the pergola.
    vn = Vine(10000, 1)
    vn.width = lambda wy: 8 + max(0, min(8, (-wy - 186) / 70))      # noqa: E731
    sy = lambda wy: -wy                                              # noqa: E731
    under, over = vine_scene(rows, sy, vn, c, above=[(58, 480), (34, 380), (30, 186)])
    body += under
    body += canopy(176, c)
    body += supra_table(W / 2, 352, c, theme)
    body += ara.mascot_svg(W / 2 + 132, 352 - 3.05 * 15, 15, "cheer")
    body += text("Tamada", W / 2, 478, 30, c["ink"], "black", anchor="middle")
    body += text("Every lesson done: the table is yours.", W / 2, 502, 14.5, c["soft"], anchor="middle")
    body += over
    for r in rows:
        body += lesson_text(r[2], r[3], sy(r[4]), c)
    body += nav(c, theme) + tab_bar(c, theme)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>\n'


# ---------------------------------------------------------------------------------------
# After a lesson: the leaf turns into green grapes, Ara hops up, the bud above opens

def hop_strip(theme):
    c = vine.VINE_COLOURS[theme]
    PW, PH = 240, 360
    out = f'<rect width="{PW * 3}" height="{PH + 40}" fill="{c["bg_top"]}"/>'
    labels = ("1  Lesson finished", "2  Green grapes, a hop", "3  The new leaf opens")
    for i, label in enumerate(labels):
        ox = i * PW
        lower, upper = 260, 260 - ROW
        nxt = upper if i == 2 else lower
        rows = [["lesson", None, {"id": "a"}, "done" if i else "next", -lower, "green", 5],
                ["lesson", None, {"id": "b"}, "next" if i == 2 else "locked", -upper, None, 6],
                ["lesson", None, {"id": "c"}, "locked", -(upper - ROW), None, 7]]
        vn = Vine(-nxt, 1)
        vn.width = lambda wy: 6 + max(0.0, -wy) / 50                 # noqa: E731
        sy = lambda wy: -wy                                            # noqa: E731
        under, over = vine_scene(rows, sy, vn, c, top_cut=-10)
        # Each panel's vine, shifted left a little and cut off above its label.
        out += (f'<defs><clipPath id="hp{i}"><rect x="30" y="0" width="{PW}" height="{PH - 14}"/></clipPath></defs>'
                f'<g clip-path="url(#hp{i})" transform="translate({ox - 30},0)">{under}{over}</g>')
        if i == 1:
            for t in range(1, 9):
                tt = t / 9
                px = ox + 30 + tt * 40
                py = lower + 10 - tt * 110 - math.sin(tt * math.pi) * 40
                out += f'<circle cx="{px:.1f}" cy="{py:.1f}" r="2.2" fill="{c["faint"]}"/>'
            out += ara.mascot_svg(ox + 56, upper - 34, 13, "cheer")
        out += text(label, ox + PW / 2, PH + 24, 15, c["ink"], anchor="middle")
        if i:
            out += f'<rect x="{ox}" y="20" width="1.2" height="{PH - 20}" fill="{c["faint"]}" opacity="0.5"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{PW * 3}" height="{PH + 40}" viewBox="0 0 {PW * 3} {PH + 40}">{out}</svg>\n'


def parts_sheet(theme):
    """Every part of the vine with its name: the lesson states, how grapes ripen, how the
    stem grows from green shoot to old bark, and the growths around it."""
    c = vine.VINE_COLOURS[theme]
    Wd, Hd = 1000, 690
    out = f'<rect width="{Wd}" height="{Hd}" fill="{c["bg_top"]}"/>'

    def label(x, y, a, b):
        return text(a, x, y, 16, c["ink"], "black", anchor="middle") + text(b, x, y + 20, 12.5, c["soft"], anchor="middle")

    # Row 1: the lesson states.
    out += vine.leaf_svg(80, 120, 72, c, "next", uid="pn") + label(80, 222, "Up next", "a fresh leaf, alive")
    out += vine.leaf_svg(205, 120, 60, c, "open", uid="po") + label(205, 222, "Open", "a calmer leaf")
    out += vine.bud_svg(310, 120, 26, c) + label(310, 222, "Locked", "a closed bud")
    for x, ripe, a, b in ((430, "green", "Done", "just finished"), (540, "blush", "Ripening", "words coming back"),
                          (650, "purple", "Ripe", "remembered")):
        out += vine.bunch_svg(x, 126, 74, c, uid=f"p{ripe}", ripe=ripe, seed=11) + label(x, 222, a, b)
    out += vine.trellis_svg(740, 990, 96, c, BAR_H)
    for x in (770, 960):
        out += (f'<path d="M{x},104 L{x},128" stroke="{c["rope"]}" stroke-width="2.4" stroke-linecap="round"/>'
                f'<circle cx="{x}" cy="104" r="3.6" fill="{c["rope"]}"/>')
    out += vine.coil_round_bar(800, 96, BAR_H, c["cane"])
    out += '<rect x="750" y="126" width="230" height="54" rx="18" fill="#7A3BC2"/>'
    out += text("Module card", 865, 160, 17, "#FFFFFF", "black", anchor="middle") + label(865, 222, "Trellis bar", "one level per module")

    # Row 2: the stem from old bark (left) to the green tip (right), lying down.
    y0 = 380
    pts = [(30 + i * 60, y0 + 10 * math.sin(i * 1.1)) for i in range(12)]
    out += vine.stem_svg(pts, lambda p: 24 - (p[0] - 30) / 690 * 17, lambda p: 1 - max(0, min(1, (p[0] - 120) / 470)), c, seed=4)
    for i in range(1, 11):
        p = pts[i]
        m = 1 - max(0, min(1, (p[0] - 120) / 470))
        w = 24 - (p[0] - 30) / 690 * 17
        out += vine.node_svg(p[0], p[1], w, 90, c, m)
    tx, ty = pts[-1][0] + 2, pts[-1][1]
    out += f'<g transform="rotate(90 {tx:.1f} {ty:.1f})">' + vine.tip_svg(tx, ty, c, size=46, side=-1, uid="ptip") + "</g>"
    for x, a, b in ((90, "Old bark", "shaggy strips"), (270, "Cane", "turning brown"), (430, "Changing", "brown patches"),
                    (590, "Green shoot", "nodes, a light streak"), (735, "Growing tip", "bronze leaves")):
        out += label(x, y0 + 64, a, b)
    out += label(500, y0 - 70, "One stem", "it browns from the bottom up, as a real vine does")

    # Row 3: growths.
    y1 = 610
    out += vine.tendril_svg(60, y1 - 20, 60, -20, c, seed=3) + label(90, y1 + 40, "Tendril", "forked, curling")
    out += vine.tendril_svg(210, y1 - 20, 60, -10, c, seed=8, spring=True) + label(245, y1 + 40, "Spring tendril", "coiled")
    for i, x in enumerate((360, 420, 480, 540)):
        out += vine.leaf_svg(x, y1 - 14, 44 + (i % 2) * 8, c, "deco", rot=(i - 1.5) * 20, uid=f"pd{i}",
                             sh=vine.leaf_shape(20 + i), colour=c["deco"][i])
    out += label(450, y1 + 40, "Leaves", "every one a little different")
    out += vine.stem_svg([(720, y1 + 14), (722, y1 - 40), (716, y1 - 80)], lambda p: 8, lambda p: 0.3, c, seed=2)
    out += vine.perch_svg(720, y1 - 20, c, R=15, reach=54) + label(650, y1 + 40, "Ara perches", "beside the next leaf")
    out += vine.leaf_svg(860, y1 - 20, 30, c, "young", rot=20, uid="py1", sh=vine.leaf_shape(5))
    out += vine.leaf_svg(900, y1 - 30, 22, c, "young", rot=-30, uid="py2", sh=vine.leaf_shape(6))
    out += label(880, y1 + 40, "Young leaves", "higher up, still unfolding")
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{Hd}" viewBox="0 0 {Wd} {Hd}">{out}</svg>\n'


def all_mockups():
    """Every picture, by file name (without extension)."""
    out = {}
    for th in ("light", "dark"):
        out[f"vine-parts-{th}"] = parts_sheet(th)
        out[f"vine-learn-{th}"] = learn_screen(th)
        out[f"vine-top-{th}"] = top_screen(th)
    out["vine-hop"] = hop_strip("light")
    return out


# ---------------------------------------------------------------------------------------
# The app's pictures (KART #15): each part of the vine on its own canvas, light and dark.
# The app draws the stem itself and places these on it (Features/Learn/VinePath.swift), so
# each canvas size and where the part sits on it must match the numbers there.

def _canvas(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'


def app_assets():
    """{asset name: {theme: svg}}. Leaves and bunches are centred on their canvas; tendrils
    start at (8, 40) heading right (VinePath.swift places them)."""
    out = {}

    def add(name, make):
        out[name] = {th: make(vine.VINE_COLOURS[th], th) for th in ("light", "dark")}

    for ripe in ("green", "blush", "purple"):
        for i in range(3):
            add(f"VineBunch{ripe.title()}{i + 1}",
                lambda c, th, ripe=ripe, i=i: _canvas(90, 90, vine.bunch_svg(45, 47, 62, c, uid="b", ripe=ripe, seed=21 + i * 7)))
    for i in range(6):
        add(f"VineLeaf{i + 1}", lambda c, th, i=i: _canvas(60, 60, vine.leaf_svg(
            30, 30, 44, c, "deco", uid="d", sh=vine.leaf_shape(40 + i), colour=c["deco"][i % 4])))
    for i in range(3):
        add(f"VineLeafYoung{i + 1}", lambda c, th, i=i: _canvas(40, 40, vine.leaf_svg(
            20, 20, 28, c, "young", uid="y", sh=vine.leaf_shape(60 + i))))
    for i in range(4):
        add(f"VineTendril{i + 1}", lambda c, th, i=i: _canvas(80, 80, vine.tendril_svg(
            8, 40, 56, 0, c, seed=70 + i, spring=(i == 3), w=2.2)))

    def top(c, th):
        body = (f'<g transform="translate(0,-116)">{canopy(176, c)}{supra_table(W / 2, 352, c, th)}'
                f'{ara.mascot_svg(W / 2 + 132, 352 - 3.05 * 15, 15, "cheer")}</g>')
        return _canvas(W, 340, body)
    add("VineTop", top)
    return out
