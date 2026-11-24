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
STEM_X = 98        # the stem's middle; it sways STEM_SWAY either side
STEM_SWAY = 20
ITEM_DX = 46       # from the stem to a lesson's picture
TEXT_X = 210       # titles start here
BAR_H = 14


def stem_x(k):
    return STEM_X + STEM_SWAY * math.sin(k * 1.3 + 0.4)


def lesson_row(lesson, state, sx, y, c, k):
    """One lesson on the vine at height y: its stalk, picture and title. state: done, next,
    open, locked."""
    ix = sx + ITEM_DX
    out = ""
    if state == "locked":
        bx, by = sx + 16, y + 2
        out += (f'<path d="M{sx:.1f},{y + 12:.1f} Q{sx + 10:.1f},{y + 10:.1f} {bx:.1f},{by + 8:.1f}" stroke="{c["shoot"]}" '
                f'stroke-width="2.4" fill="none" stroke-linecap="round"/>')
        out += vine.bud_svg(bx + 2, by - 2, 22, c)
    else:
        top = y - (34 if state == "done" else 30)
        out += (f'<path d="M{sx:.1f},{y - 10:.1f} C{sx + 18:.1f},{y - 30:.1f} {ix - 4:.1f},{top - 14:.1f} {ix:.1f},{top + 4:.1f}" '
                f'stroke="{c["wood"] if state == "done" else c["leaf_deep"]}" stroke-width="3.2" fill="none" stroke-linecap="round"/>')
        if state == "done":
            out += vine.bunch_svg(ix, y + 4, 66, c, uid=f"g{lesson['id']}", tilt=4 if k % 2 else -4)
        else:
            out += vine.leaf_svg(ix, y + 2, 66 if state == "next" else 56, c, state, rot=6 if k % 2 else -6,
                                 uid=f"l{lesson['id']}")
    title_col = c["faint"] if state == "locked" else c["ink"]
    out += text(fit(lesson["title"], 17, W - TEXT_X - 16), TEXT_X, y - 1, 17, title_col, "black")
    out += text(fit(lesson["subtitle"], 12.5, W - TEXT_X - 16, "regular"), TEXT_X, y + 17, 12.5,
                c["faint"] if state == "locked" else c["soft"], "regular")
    return out


def tendril(sx, y, c, side=-1, colour=None):
    return (f'<path d="{vine.tendril_d(sx, y, 30, side)}" stroke="{colour or c["shoot"]}" stroke-width="2" '
            f'fill="none" stroke-linecap="round"/>')


def learn_screen(theme, upto=("vocabulary", 2)):
    """The Learn screen with the vine: all of the first module and `upto` lessons of the
    named module done; the next lesson in the middle of the screen with Ara beside it."""
    c = vine.VINE_COLOURS[theme]
    mods = course()
    # Course order, bottom to top: (kind, module, lesson, state, world y). World y grows upward.
    rows, y, finished = [], 0.0, True
    for m in mods:
        # The row's y is the trellis bar; the card hangs below it, the lessons grow above.
        y += card_height(m) + 40
        rows.append(("card", m, None, None, y))
        y += 76
        for i, l in enumerate(m["lessons"]):
            if m["id"] == upto[0]:
                state = "done" if i < upto[1] else ("next" if i == upto[1] else "locked")
                finished = False if i >= upto[1] else finished
            else:
                state = "done" if finished else "locked"
            rows.append(("lesson", m, l, state, y))
            y += ROW
        y += 10
        if m["id"] == upto[0]:
            finished = False
    nxt = next(r for r in rows if r[3] == "next")
    shift = 372 + nxt[4]            # the next lesson sits at screen y 372
    sy = lambda wy: shift - wy      # noqa: E731

    body = background(c, theme)
    # Which rows are on screen (with a margin for the stem to run off the edges).
    vis = [r for r in rows if -200 < sy(r[4]) < H + 260]
    # The stem: old wood up to the next lesson, a young green shoot above it.
    pts_old, pts_young, k_of = [], [], {}
    for k, r in enumerate(rows):
        k_of[id(r)] = k
    for r in vis:
        k = k_of[id(r)]
        p = (stem_x(k), sy(r[4]))
        if r[4] <= nxt[4]:
            pts_old.append(p)
        if r[4] >= nxt[4]:
            pts_young.append(p)
    # (Both run bottom to top, as the rows do.)
    if len(pts_young) > 1:
        body += vine.stem_svg(pts_young, 5, 3, c["shoot"], c["shoot"])
    if pts_old:
        body += vine.stem_svg([(pts_old[0][0], H + 200)] + pts_old, 15, 8, c["wood"], c["wood_deep"], c["wood_light"])
    # Trellis bars and module cards (in front of the stem), then lessons.
    for r in vis:
        if r[0] != "card":
            continue
        m = r[1]
        y0 = sy(r[4])               # the bar's level
        done = sum(1 for q in rows if q[0] == "lesson" and q[1] is m and q[3] == "done")
        card, ch = module_card(m, 20, y0 + 30, W - 40, done, c, theme)
        ropes = "".join(f'<path d="M{x},{y0 + 8} L{x},{y0 + 32}" stroke="{c["rope"]}" stroke-width="2.4" stroke-linecap="round"/>'
                        f'<circle cx="{x}" cy="{y0 + 8}" r="3.6" fill="{c["rope"]}"/>' for x in (56, W - 56))
        body += ropes + vine.trellis_svg(-12, W + 12, y0, c, BAR_H) + card
        # The vine winds once round the bar on its way up.
        k = k_of[id(r)]
        sx = stem_x(k)
        body += (f'<path d="M{sx - 9:.1f},{y0 + BAR_H + 3:.1f} C{sx - 2:.1f},{y0 - 8:.1f} {sx + 14:.1f},{y0 - 2:.1f} {sx + 9:.1f},{y0 + BAR_H - 2:.1f}" '
                 f'stroke="{c["wood_deep"] if r[4] <= nxt[4] else c["shoot"]}" stroke-width="4" fill="none" stroke-linecap="round"/>')
    for r in vis:
        if r[0] != "lesson":
            continue
        k = k_of[id(r)]
        sx, yy = stem_x(k), sy(r[4])
        if k % 2 == 0 and r[3] != "next":
            body += tendril(sx - 3, yy + 32, c, -1, c["shoot"] if r[3] != "locked" else c["shoot_faint"])
        body += lesson_row(r[2], r[3], sx, yy, c, k)
        if r[3] == "next":
            body += vine.perch_svg(sx - 2, yy + 22, c, R=14, reach=54)
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
    """The full vine overhead: a pergola beam hidden in leaves, bunches hanging under it."""
    out = vine.trellis_svg(-12, W + 12, y, c, BAR_H)
    leaves = [(-6, 0), (30, -14), (64, 4), (104, -10), (140, 6), (176, -12), (214, 2), (252, -14), (288, 4),
              (326, -10), (362, 4), (398, -8)]
    for i, (x, dy) in enumerate(leaves):
        out += vine.leaf_svg(x, y + dy - 6, 52, c, "open", rot=(i % 3 - 1) * 25, uid=f"cb{i}")
    for i, (x, dy) in enumerate(leaves[::2]):
        out += vine.leaf_svg(x + 18, y + dy + 22, 46, c, "open", rot=(i % 2) * 30 - 15, uid=f"cf{i}")
    for i, x in enumerate((48, 132, 222, 300, 372)):
        out += vine.bunch_svg(x, y + 62 + (i % 2) * 12, 52, c, uid=f"cg{i}", tilt=(i % 3 - 1) * 6)
    return out


def top_screen(theme):
    """The top of Learn once every lesson is done: the last lessons as grapes, then the full
    vine over a supra table, with Ara cheering on it: the Tamada stage."""
    c = vine.VINE_COLOURS[theme]
    m = course()[-1]
    body = background(c, theme)
    lessons = m["lessons"][::-1][:3]                 # the last three, top first
    ys = [574 + i * ROW for i in range(len(lessons))]
    ks = [len(m["lessons"]) - 1 - i for i in range(len(lessons))]
    pts = [(stem_x(k), y) for k, y in zip(ks, ys)][::-1]
    pts = [(pts[0][0], H + 200)] + pts + [(48, 500), (30, 380), (34, 200)]   # up the left, past the words
    body += vine.stem_svg(pts, 15, 9, c["wood"], c["wood_deep"], c["wood_light"])
    body += canopy(176, c)
    body += supra_table(W / 2, 352, c, theme)
    body += ara.mascot_svg(W / 2 + 132, 352 - 3.05 * 15, 15, "cheer")
    # The stage, in the gold of rewards.
    body += text("Tamada", W / 2, 478, 30, c["ink"], "black", anchor="middle")
    body += text("Every lesson done: the table is yours.", W / 2, 502, 14.5, c["soft"], anchor="middle")
    for k, y, l in zip(ks, ys, lessons):
        if k % 2 == 0:
            body += tendril(stem_x(k) - 3, y + 32, c)
        body += lesson_row(l, "done", stem_x(k), y, c, k)
    body += nav(c, theme) + tab_bar(c, theme)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>\n'


# ---------------------------------------------------------------------------------------
# After a lesson: Ara hops up to the next leaf and it unfolds

def hop_strip(theme):
    """Three moments side by side: before (Ara by the leaf up next), the hop (the leaf has
    ripened into grapes, Ara in the air, the bud above opening), after (Ara on the new leaf)."""
    c = vine.VINE_COLOURS[theme]
    PW, PH = 230, 330
    out = f'<rect width="{PW * 3}" height="{PH + 40}" fill="{c["bg_top"]}"/>'
    for i, label in enumerate(("1  Lesson finished", "2  Ripe, and a hop", "3  The new leaf opens")):
        ox = i * PW
        sx = lambda y: ox + 112 + 10 * math.sin(y / 60)   # noqa: E731
        lower, upper = 250, 140
        grown = upper - 30 if i == 2 else upper + 20       # the old wood reaches the new leaf
        out += vine.stem_svg([(sx(grown), grown), (sx(60), 60), (sx(10), 10)], 5, 3, c["shoot"], c["shoot"])
        out += vine.stem_svg([(sx(PH - 8), PH - 8), (sx(lower), lower), (sx(grown), grown)], 12, 9,
                             c["wood"], c["wood_deep"], c["wood_light"])
        bx = sx(lower) + ITEM_DX
        out += (f'<path d="M{sx(lower):.1f},{lower - 10} C{sx(lower) + 18:.1f},{lower - 30} {bx - 4:.1f},{lower - 44} {bx:.1f},{lower - 26}" '
                f'stroke="{c["wood"] if i else c["leaf_deep"]}" stroke-width="3.2" fill="none" stroke-linecap="round"/>')
        if i == 0:
            out += vine.leaf_svg(bx, lower + 2, 66, c, "next", uid=f"h{i}a")
            out += vine.perch_svg(sx(lower) - 2, lower + 22, c, R=14, reach=54)
        else:
            out += vine.bunch_svg(bx, lower + 4, 66, c, uid=f"h{i}g")
        ux = sx(upper) + ITEM_DX
        if i < 2:
            k = 22 if i == 0 else 30
            out += vine.bud_svg(sx(upper) + 18, upper, k, c)
        if i == 1:
            # Ara mid-hop, cheering, with its path drawn as dots.
            for t in range(1, 9):
                tt = t / 9
                px = ox + 30 + tt * 40
                py = lower + 10 - tt * 110 - math.sin(tt * math.pi) * 40
                out += f'<circle cx="{px:.1f}" cy="{py:.1f}" r="2.2" fill="{c["faint"]}"/>'
            out += ara.mascot_svg(ox + 58, upper - 30, 13, "cheer")
        if i == 2:
            out += (f'<path d="M{sx(upper):.1f},{upper - 10} C{sx(upper) + 18:.1f},{upper - 30} {ux - 4:.1f},{upper - 44} {ux:.1f},{upper - 26}" '
                    f'stroke="{c["leaf_deep"]}" stroke-width="3.2" fill="none" stroke-linecap="round"/>')
            out += vine.leaf_svg(ux, upper + 2, 66, c, "next", uid=f"h{i}b")
            out += vine.perch_svg(sx(upper) - 2, upper + 22, c, R=14, reach=54)
        out += text(label, ox + PW / 2, PH + 24, 15, c["ink"], anchor="middle")
        if i:
            out += f'<rect x="{ox}" y="20" width="1.2" height="{PH - 20}" fill="{c["faint"]}" opacity="0.5"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{PW * 3}" height="{PH + 40}" viewBox="0 0 {PW * 3} {PH + 40}">{out}</svg>\n'


def parts_sheet(theme):
    """Every part of the vine with its name: what each lesson state looks like."""
    c = vine.VINE_COLOURS[theme]
    Wd, Hd = 980, 330
    out = f'<rect width="{Wd}" height="{Hd}" fill="{c["bg_top"]}"/>'
    out += vine.leaf_svg(80, 140, 72, c, "next", uid="pn")
    out += vine.leaf_svg(205, 140, 60, c, "open", uid="po")
    out += vine.bunch_svg(325, 146, 72, c, uid="pg")
    out += vine.bud_svg(430, 140, 26, c)
    out += vine.stem_svg([(560, 232), (550, 190), (566, 130), (556, 60)], 15, 9, c["wood"], c["wood_deep"], c["wood_light"])
    out += vine.stem_svg([(556, 60), (552, 20)], 5, 4, c["shoot"], c["shoot"])
    out += f'<path d="{vine.tendril_d(552, 214, 26, -1)}" stroke="{c["shoot"]}" stroke-width="2" fill="none" stroke-linecap="round"/>'
    out += vine.perch_svg(560, 170, c, R=15, reach=54)
    out += vine.trellis_svg(650, 960, 120, c, BAR_H)
    for x in (690, 920):
        out += (f'<path d="M{x},{128} L{x},{152}" stroke="{c["rope"]}" stroke-width="2.4" stroke-linecap="round"/>'
                f'<circle cx="{x}" cy="128" r="3.6" fill="{c["rope"]}"/>')
    out += '<rect x="660" y="150" width="290" height="60" rx="18" fill="#7A3BC2"/>'
    out += text("Module card", 805, 187, 17, "#FFFFFF", "black", anchor="middle")
    for x, a, b in ((80, "Up next", "a fresh leaf, alive"), (205, "Open", "a calmer leaf"), (325, "Done", "a ripe bunch"),
                    (430, "Locked", "a closed bud"), (540, "Ara perches", "beside the next leaf"),
                    (805, "Trellis bar", "one level per module")):
        out += text(a, x, 262, 16, c["ink"], "black", anchor="middle")
        out += text(b, x, 282, 12.5, c["soft"], anchor="middle")
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
