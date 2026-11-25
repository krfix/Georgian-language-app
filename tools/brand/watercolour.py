"""A painted (watercolour) grapevine for the Learn path, generated (KART #15, round 3).

The owner found the vector vine too "gamey" and showed a watercolour vine as the look to aim
for. This paints in code: every shape gets wobbly edges, a mottled wash, darker pigment
pooling at its edges and glazes that darken where they overlap (SVG filters and multiply
blending, rendered by the Chromium that comes with Playwright, since cairosvg can't do
filters). Nothing is traced or copied from any picture.

- tile(kind): a vertical strip of vine, TILE_H points tall, that repeats seamlessly (the stem,
  side leaves and tendrils; no lesson pictures). kind "old" is woody brown cane, "young" a
  green shoot with the same shape, so the app can fade from one to the other at the lesson
  up next.
- parts: grape bunches (green, blushing, ripe), the leaf up next, a bud, each on its own.

Run with make_brand.py --paint (writes brand/paint/).
"""
import io
import json
import math
import os
import random
import subprocess
import tempfile

from PIL import Image

import vine

HERE = os.path.dirname(os.path.abspath(__file__))
ROW = 92
TILE_ROWS = 8
TILE_H = ROW * TILE_ROWS          # 736 points: the strip repeats after this
TILE_W = 220                      # the vine's lane, from the left edge
OVERLAP = 120                     # painted beyond the tile, then blended into its top

PAINT = {
    "bark": ("#A0714B", "#6E4A2E"), "cane": ("#C29469", "#8A603C"), "bark2": ("#8B5E3C", "#5E3D24"),
    "shoot": ("#8DBA5A", "#5E8F38"),
    "leaf": ("#86B84E", "#4F8A33", "#C4DC74"), "leaf2": ("#A3C658", "#62973A", "#DCEB95"),
    "leaf3": ("#6FA65A", "#437F3A", "#A9CF7E"), "leaf4": ("#B5CF62", "#7A9E3C", "#E4EFA8"),
    "tendril": "#8FBF62",
    "purple": ("#8A4E8E", "#5E2F6B", "#C59AC7"), "green": ("#A9CC5C", "#6E9A35", "#E1EFA6"),
}


def stem_x(y):
    """The stem's middle at height y (repeats every TILE_H)."""
    return 96 + 16 * math.sin(2 * math.pi * y / (TILE_H / 2)) + 5 * math.sin(2 * math.pi * y / (TILE_H / 4) + 1)


def node_y(r):
    """The node of lesson row r inside the tile (row centre minus 16, as the app's rows)."""
    return r * ROW + ROW / 2 - 16


FILTERS = """
<filter id="wash{n}" x="-30%" y="-30%" width="160%" height="160%" color-interpolation-filters="sRGB">
  <feTurbulence type="fractalNoise" baseFrequency="{f}" numOctaves="3" seed="{s}" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="{d}" xChannelSelector="R" yChannelSelector="G" result="w"/>
  <feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="2" seed="{s2}" result="n2"/>
  <feColorMatrix in="n2" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -1.6 1.45" result="m"/>
  <feComposite in="w" in2="m" operator="in" result="mottled"/>
  <feMorphology in="w" operator="erode" radius="{e}" result="er"/>
  <feComposite in="w" in2="er" operator="out" result="edge"/>
  <feGaussianBlur in="edge" stdDeviation="0.7" result="edgeb"/>
  <feGaussianBlur in="mottled" stdDeviation="0.5" result="soft"/>
  <feMerge><feMergeNode in="soft"/><feMergeNode in="edgeb"/><feMergeNode in="edgeb"/></feMerge>
</filter>"""


def filters():
    out = ""
    for n, (f, d, e) in enumerate(((0.03, 7, 1.6), (0.05, 4, 1.2), (0.02, 10, 2.0), (0.08, 3, 0.8))):
        out += FILTERS.format(n=n, f=f, d=d, e=e, s=n * 7 + 3, s2=n * 5 + 11)
    return out


def g(body, flt=0, op=0.82):
    """A wash: shapes painted with filter `flt`, glazed (multiplied) over what's below."""
    return f'<g filter="url(#wash{flt})" style="mix-blend-mode:multiply" opacity="{op}">{body}</g>'


def _leaf(cx, cy, size, rot, seed, tone="leaf", veins=True):
    rnd = random.Random(seed)
    base, deep, light = PAINT[tone]
    sh = vine.leaf_shape(seed)
    sh["tooth"] *= 1.3
    out = g(f'<path d="{vine.leaf_d(cx, cy, size, rot, sh)}" fill="{base}"/>', 0, 0.78)
    # A second, lighter glaze off to one side: the wash never covers evenly.
    dx, dy = rnd.uniform(-3, 3), rnd.uniform(-3, 3)
    out += g(f'<path d="{vine.leaf_d(cx + dx, cy + dy, size * 0.8, rot + rnd.uniform(-12, 12), sh)}" fill="{light}"/>', 1, 0.45)
    out += g(f'<path d="{vine.leaf_d(cx, cy, size, rot, sh, half=1)}" fill="{deep}"/>', 1, 0.28)
    if veins:
        a0 = math.radians(rot)
        rp = lambda lx, ly: (cx + lx * math.cos(a0) - ly * math.sin(a0), cy + lx * math.sin(a0) + ly * math.cos(a0))  # noqa: E731
        rx, ry = rp(0, -size * 0.12)
        v = ""
        for phi, k in ((0, 0.8), (66, 0.74), (-66, 0.74), (126, 0.6), (-126, 0.6)):
            rr = size / 2.2 * vine._leaf_r(phi, sh) * k
            tx, ty = rp(rr * math.cos(math.radians(phi + 90)), rr * math.sin(math.radians(phi + 90)))
            mx, my = (rx + tx) / 2 + (ty - ry) * 0.08, (ry + ty) / 2 - (tx - rx) * 0.08
            v += f'<path d="M{rx:.1f},{ry:.1f} Q{mx:.1f},{my:.1f} {tx:.1f},{ty:.1f}" stroke="{deep}" stroke-width="0.8" fill="none"/>'
            # Side veins: short strokes off each main vein.
            for t in (0.35, 0.6):
                px, py = rx + (tx - rx) * t, ry + (ty - ry) * t
                ang = math.atan2(ty - ry, tx - rx)
                for sd in (-1, 1):
                    qx, qy = px + math.cos(ang + sd * 0.7) * size * 0.1, py + math.sin(ang + sd * 0.7) * size * 0.1
                    v += f'<path d="M{px:.1f},{py:.1f} L{qx:.1f},{qy:.1f}" stroke="{deep}" stroke-width="0.6" fill="none"/>'
        out += f'<g filter="url(#wash3)" opacity="0.55">{v}</g>'
    return out


def _tendril(x, y, size, ang, seed, colour):
    pts = []
    rnd = random.Random(seed)
    a = math.radians(ang)
    bend = rnd.uniform(-0.6, 0.6)
    L = size * 0.6
    for i in range(16):
        t = i / 15
        pts.append((x + math.cos(a + bend * t) * L * t, y + math.sin(a + bend * t) * L * t))
    ex, ey = pts[-1]
    side = 1 if rnd.random() < 0.5 else -1
    r0 = size * rnd.uniform(0.12, 0.18)
    aa = a + bend
    cx, cy = ex + math.cos(aa + side * math.pi / 2) * r0, ey + math.sin(aa + side * math.pi / 2) * r0
    st = math.atan2(ey - cy, ex - cx)
    turns = rnd.uniform(1.4, 2.4)
    for i in range(1, 50):
        t = i / 49
        th = st + side * t * turns * 2 * math.pi
        r = r0 * (1 - 0.75 * t)
        pts.append((cx + r * math.cos(th), cy + r * math.sin(th)))
    d = "M" + " L".join(f"{px:.1f},{py:.1f}" for px, py in pts)
    return g(f'<path d="{d}" stroke="{colour}" stroke-width="1.3" fill="none" stroke-linecap="round"/>', 3, 0.85)


def _stem(kind, y0, y1):
    """The cane from y0 to y1: two or three strands twisting round each other, like an old
    vine; for 'young', one smooth green shoot along the same line."""
    out = ""
    ys = [y0 + (y1 - y0) * i / 160 for i in range(161)]
    if kind == "young":
        base, deep = PAINT["shoot"]
        d = "M" + " L".join(f"{stem_x(y):.1f},{y:.1f}" for y in ys)
        out += g(f'<path d="{d}" stroke="{base}" stroke-width="6.5" fill="none" stroke-linecap="round"/>', 1, 0.85)
        d2 = "M" + " L".join(f"{stem_x(y) + 1.8:.1f},{y:.1f}" for y in ys)
        out += g(f'<path d="{d2}" stroke="{deep}" stroke-width="2" fill="none"/>', 3, 0.45)
        return out
    for k, (w, ph, tone) in enumerate(((7.5, 0, "bark"), (5.5, 2.1, "cane"), (4, 4.2, "bark2"))):
        base, deep = PAINT[tone]
        d = "M" + " L".join(f"{stem_x(y) + 4.5 * math.sin(2 * math.pi * y / (ROW * 1.5) + ph):.1f},{y:.1f}" for y in ys)
        out += g(f'<path d="{d}" stroke="{base}" stroke-width="{w}" fill="none" stroke-linecap="round"/>', 1, 0.78)
        out += g(f'<path d="{d}" stroke="{deep}" stroke-width="{w * 0.22:.1f}" fill="none" transform="translate(1.6,0)"/>', 3, 0.55)
    # Bark texture: short broken lines along the cane.
    rnd = random.Random(9)
    tex = ""
    y = y0
    while y < y1:
        L = rnd.uniform(6, 16)
        x = stem_x(y) + rnd.uniform(-4, 4)
        tex += f'<path d="M{x:.1f},{y:.1f} L{stem_x(y + L) + (x - stem_x(y)):.1f},{y + L:.1f}" stroke="#5A3A22" stroke-width="0.7"/>'
        y += rnd.uniform(4, 10)
    out += g(tex, 3, 0.45)
    return out


def _stalked(stem_pt, cx, cy, size, rot, seed, tone, kind, veins=True):
    """A leaf on its stalk, joined to the stem at stem_pt."""
    a = math.radians(rot)
    nx, ny = cx + size * 0.32 * math.sin(a), cy - size * 0.32 * math.cos(a)
    sx, sy = stem_pt
    col = "#7FA653" if kind == "young" else "#8C9A5A"
    mx, my = (sx + nx) / 2, min(sy, ny) - 6
    stalk = g(f'<path d="M{sx:.1f},{sy:.1f} Q{mx:.1f},{my:.1f} {nx:.1f},{ny:.1f}" stroke="{col}" stroke-width="1.6" fill="none" '
              f'stroke-linecap="round"/>', 3, 0.8)
    return stalk + _leaf(cx, cy, size, rot, seed, tone, veins)


def tile_svg(kind):
    """The repeating strip, drawn OVERLAP points too tall (the extra is blended into the top)."""
    rnd = random.Random(5)
    H = TILE_H + OVERLAP
    body = ""
    stem = _stem(kind, -40, H + 40)
    leaves, tendrils = "", ""
    tone_tendril = PAINT["tendril"] if kind == "young" else "#9CB868"
    # Everything is placed for rows -1..TILE_ROWS+1 so whatever crosses the tile's top or
    # bottom is painted on both sides of the seam.
    for r in range(-1, TILE_ROWS + 2):
        rr = r % TILE_ROWS
        q = random.Random(100 + rr)
        y = node_y(r)
        x = stem_x(y)
        tones = ("leaf", "leaf2", "leaf3", "leaf4")
        # The big leaf opposite the lesson, out to the left, at any angle.
        leaves += _stalked((x - 2, y), x - 38 - q.uniform(0, 12), y + q.uniform(-8, 8), q.uniform(56, 74), q.uniform(-10, 70),
                           300 + rr, tones[rr % 4], kind)
        yb = y + ROW / 2
        xb = stem_x(yb)
        # Between lessons: a leaf on the left or tucked behind the stem on the right.
        if rr % 3 == 1:
            leaves += _stalked((xb + 2, yb), xb + 26, yb + 6, q.uniform(36, 46), q.uniform(-70, -20), 400 + rr,
                               tones[(rr + 1) % 4], kind)
        else:
            leaves += _stalked((xb - 2, yb), xb - 30 - q.uniform(0, 12), yb + 12, q.uniform(40, 54), q.uniform(20, 80),
                               400 + rr, tones[(rr + 2) % 4], kind)
        # Tendrils: short curls, and now and then a long arc swinging out with a curl at its end.
        if rr % 3 != 2:
            tendrils += _tendril(xb + 2, yb, q.uniform(44, 60), q.uniform(-40, 10), 500 + rr, tone_tendril)
        else:
            tendrils += _tendril(xb - 6, yb - 4, q.uniform(80, 110), q.uniform(195, 225), 600 + rr, tone_tendril)
        if rr % 4 == 0:
            leaves += _leaf(xb - 72 - q.uniform(0, 8), yb - 22, q.uniform(22, 30), q.uniform(-40, 40), 700 + rr,
                            "leaf4", veins=False)
    _ = rnd
    body = tendrils + leaves + stem
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{TILE_W}" height="{H}" viewBox="0 0 {TILE_W} {H}">'
            f'<defs>{filters()}</defs>{body}</svg>')


def bunch_svg(ripe, seed=3, size=64):
    """A painted bunch on a 90 x 90 canvas: grapes as overlapping round glazes with the paper
    left white for the light."""
    rnd = random.Random(seed)
    W = 90
    cx, cy = 45, 47
    s = size
    r = s * 0.13
    rows = [4, 4, 3, 3, 2, 1] if seed % 2 else [4, 3, 3, 2, 2, 1]
    grapes, y = [], -0.34
    for ri, k in enumerate(rows):
        for j in range(k):
            grapes.append(((j - (k - 1) / 2) * 0.235 + rnd.uniform(-0.03, 0.03), y + rnd.uniform(-0.02, 0.02), rnd.uniform(0.9, 1.1)))
        y += 0.16
    wing = 1 if rnd.random() < 0.5 else -1
    for x, yy in ((0.5, -0.28), (0.58, -0.13)):
        grapes.append((x * wing, yy, rnd.uniform(0.85, 0.98)))
    body = g(f'<path d="M{cx},{cy - s * 0.3} Q{cx + 3},{cy - s * 0.46} {cx - 2},{cy - s * 0.56}" stroke="#7A5A3A" '
             f'stroke-width="2.4" fill="none" stroke-linecap="round"/>', 3, 0.8)
    # First a loose wash in the bunch's shape, the shadow between the grapes.
    first = {"green": PAINT["green"], "blush": PAINT["purple"], "purple": PAINT["purple"]}[ripe]
    hull = " ".join(f"{cx + x * s:.1f},{cy + yy * s:.1f}" for x, yy, _ in grapes)
    body += g(f'<polygon points="{hull}" fill="{first[1]}" stroke="{first[1]}" stroke-width="{r * 1.6:.1f}" stroke-linejoin="round"/>', 2, 0.32)
    order = sorted(grapes, key=lambda q: q[1] + rnd.uniform(-0.08, 0.08))
    for (x, yy, k) in order:
        gx, gy, gr = cx + x * s, cy + yy * s, r * k
        if ripe == "blush":
            p = rnd.random()
            tone = "purple" if p < 0.35 - yy * 0.6 else ("green" if p > 0.75 - yy * 0.3 else "mid")
        else:
            tone = ripe
        if tone == "mid":
            base, deep, light = "#A8678A", "#6E3D63", "#D8B3C4"
        else:
            base, deep, light = PAINT[tone]
        base = vine.mix(base, light if rnd.random() < 0.5 else deep, rnd.uniform(0, 0.3))
        body += g(f'<circle cx="{gx:.1f}" cy="{gy:.1f}" r="{gr:.1f}" fill="{base}"/>', 1, rnd.uniform(0.6, 0.85))
        body += g(f'<path d="M{gx - gr * 0.3:.1f},{gy + gr * 0.9:.1f} A{gr:.1f},{gr:.1f} 0 0 0 {gx + gr * 0.9:.1f},{gy + gr * 0.0:.1f}" '
                  f'stroke="{deep}" stroke-width="{gr * 0.4:.1f}" fill="none"/>', 3, 0.4)
        if rnd.random() < 0.55:
            body += f'<circle cx="{gx - gr * 0.38:.1f}" cy="{gy - gr * 0.38:.1f}" r="{gr * 0.18:.1f}" fill="#FFFDF7" opacity="0.7"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">'
            f'<defs>{filters()}</defs>{body}</svg>')


def leaf_next_svg():
    """The lesson up next: a fresh leaf with a soft green halo, on a 100 x 100 canvas."""
    halo = g('<circle cx="50" cy="50" r="44" fill="#CFE8B0"/>', 2, 0.55)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
            f'<defs>{filters()}</defs>{halo}{_leaf(50, 52, 64, 4, 77, "leaf2")}</svg>')


def bud_svg():
    d = vine.smooth_d([(15, 4), (24, 14), (21, 24), (15, 27), (9, 24), (6, 14)])
    body = g(f'<path d="{d}" fill="#B7C98F"/>', 1, 0.8)
    body += g('<path d="M15,4 Q12,16 14,26" stroke="#7F9A5C" stroke-width="1.4" fill="none"/>', 3, 0.6)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 30 30">'
            f'<defs>{filters()}</defs>{body}</svg>')


# ---------------------------------------------------------------------------------------
# Rendering (Chromium through Playwright, for the SVG filters and blending)

RENDER_JS = """
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch();
  for (const j of jobs) {
    const page = await browser.newPage({ viewport: { width: j.w, height: j.h }, deviceScaleFactor: j.scale });
    await page.setContent(`<html><body style="margin:0;background:transparent">${fs.readFileSync(j.svg, 'utf8')}</body></html>`);
    await page.locator('svg').screenshot({ path: j.png, omitBackground: true });
    await page.close();
  }
  await browser.close();
})();
"""


def render(items, scale=3):
    """items: {name: svg}. Returns {name: PIL image}, `scale` pixels to the point."""
    with tempfile.TemporaryDirectory() as tmp:
        jobs = []
        for name, svg in items.items():
            p = os.path.join(tmp, f"{name}.svg")
            with open(p, "w") as f:
                f.write(svg)
            w = float(svg.split('width="', 1)[1].split('"', 1)[0])
            h = float(svg.split('height="', 1)[1].split('"', 1)[0])
            jobs.append(dict(svg=p, png=os.path.join(tmp, f"{name}.png"), w=int(math.ceil(w)), h=int(math.ceil(h)), scale=scale))
        jf = os.path.join(tmp, "jobs.json")
        with open(jf, "w") as f:
            json.dump(jobs, f)
        js = os.path.join(tmp, "render.js")
        with open(js, "w") as f:
            f.write(RENDER_JS)
        env = dict(os.environ)
        subprocess.run(["node", js, jf], check=True, env=env, cwd=tmp)
        return {name: Image.open(os.path.join(tmp, f"{name}.png")).convert("RGBA").copy() for name in items}


def seamless(im, scale):
    """The painted strip is OVERLAP points taller than the tile, and the drawing repeats
    every TILE_H: fade the overflow into the tile's top so the bottom runs on into the top."""
    H, O = TILE_H * scale, OVERLAP * scale
    out = im.crop((0, 0, im.width, H)).copy()
    extra = im.crop((0, H, im.width, H + O))
    top = out.crop((0, 0, im.width, O))
    mask = Image.linear_gradient("L").resize((im.width, O))       # 0 at the seam, 255 further in
    out.paste(Image.composite(top, extra, mask), (0, 0))
    return out


def paint_all(scale=3):
    """{name: PIL image} for every painted part."""
    items = {"tile-old": tile_svg("old"), "tile-young": tile_svg("young"), "leaf-next": leaf_next_svg(), "bud": bud_svg()}
    for ripe in ("green", "blush", "purple"):
        for i in range(3):
            items[f"bunch-{ripe}-{i + 1}"] = bunch_svg(ripe, seed=21 + i * 7)
    ims = render(items, scale)
    for k in ("tile-old", "tile-young"):
        ims[k] = seamless(ims[k], scale)
    return ims


# ---------------------------------------------------------------------------------------
# A still mock-up of the Learn screen with the painted vine

def _data(im):
    import base64
    b = io.BytesIO()
    im.save(b, "PNG")
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def learn_mock(ims, scale=3):
    """The Learn screen (402 x 874 points) with the painted strip repeating, fading from old
    cane to green shoot at the lesson up next, and the real course text."""
    import ara
    import vine_screens as vs
    W, H = vs.W, vs.H
    c = vine.VINE_COLOURS["light"]
    mods = vs.course()
    voc = next(m for m in mods if m["id"] == "vocabulary")
    upto = 3                                      # three Vocabulary lessons done
    next_y = 340                                  # the next lesson's row centre on screen
    rows = []                                     # (lesson, state, ripeness, row centre)
    for i, l in enumerate(voc["lessons"][:8]):
        yc = next_y + (upto - i) * ROW
        state = "done" if i < upto else ("next" if i == upto else "locked")
        rows.append((l, state, {1: "green", 2: "blush"}.get(upto - i, "purple"), yc))
    bar_y = rows[0][3] + ROW / 2 + vs.BAR_H + 20  # the trellis bar under the first lesson
    # The strip: its row r has its node at r*ROW + 30; line it up with the lessons' rows.
    off = (next_y - ROW / 2) % TILE_H - TILE_H
    tiles_old = tiles_young = ""
    y = off
    while y < H:
        tiles_old += f'<image href="{_data(ims["tile-old"])}" x="0" y="{y:.1f}" width="{TILE_W}" height="{TILE_H}"/>'
        tiles_young += f'<image href="{_data(ims["tile-young"])}" x="0" y="{y:.1f}" width="{TILE_W}" height="{TILE_H}"/>'
        y += TILE_H
    fade = (f'<linearGradient id="grow" x1="0" y1="0" x2="0" y2="{H}" gradientUnits="userSpaceOnUse">'
            f'<stop offset="{(next_y - 10) / H:.3f}" stop-color="#fff"/><stop offset="{(next_y + 170) / H:.3f}" stop-color="#000"/>'
            f'</linearGradient><mask id="young"><rect width="{W}" height="{H}" fill="url(#grow)"/></mask>')
    paper = ('<filter id="paper" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="0.9" '
             'numOctaves="2" seed="4"/><feColorMatrix type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.36  0 0 0 0 0.25  0 0 0 0.10 0"/>'
             '</filter>')
    body = (f'<rect width="{W}" height="{H}" fill="#FBF4E8"/><rect width="{W}" height="{H}" filter="url(#paper)"/>'
            f'{tiles_old}<g mask="url(#young)">{tiles_young}</g>')
    items = ""
    for l, state, ripe, yc in rows:
        sx = stem_x((yc - 16 - off) % TILE_H)
        ix = sx + 46
        if state == "done":
            k = rows.index((l, state, ripe, yc)) % 3 + 1
            items += (f'<path d="M{sx + 2:.1f},{yc - 16:.1f} Q{sx + 20:.1f},{yc - 40:.1f} {ix:.1f},{yc - 30:.1f}" stroke="#8C7A4A" '
                      f'stroke-width="2" fill="none"/>')
            items += f'<image href="{_data(ims[f"bunch-{ripe}-{k}"])}" x="{ix - 45:.1f}" y="{yc + 4 - 45:.1f}" width="90" height="90"/>'
        elif state == "next":
            items += f'<image href="{_data(ims["leaf-next"])}" x="{ix - 50:.1f}" y="{yc + 2 - 50:.1f}" width="100" height="100"/>'
            # Ara, painted like the vine, on a twig to the left of the stem.
            twig = f'<path d="M{sx - 2:.1f},{yc + 14:.1f} Q{sx - 28:.1f},{yc + 24:.1f} {sx - 56:.1f},{yc + 22:.1f}" stroke="#9A6B45" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
            R = 14
            o = ara.POSES["hello"]
            a = math.radians(o["lean"])
            foot = (0.15 * math.cos(a) - 2.98 * math.sin(a), 0.15 * math.sin(a) + 2.98 * math.cos(a))
            px, py = sx - 34, yc + 21
            parrot = ara.mascot_svg(px - foot[0] * R, py - foot[1] * R, R, "hello")
            items += f'<g filter="url(#wash1)" opacity="0.93">{parrot}</g>' + g(twig, 1, 0.85)
        else:
            items += f'<image href="{_data(ims["bud"])}" x="{sx + 6:.1f}" y="{yc - 40:.1f}" width="30" height="30"/>'
        col = c["faint"] if state == "locked" else c["ink"]
        items += vs.text(vs.fit(l["title"], 17, W - vs.TEXT_X - 16), vs.TEXT_X, yc - 1, 17, col, "black")
        items += vs.text(vs.fit(l["subtitle"], 12.5, W - vs.TEXT_X - 16, "regular"), vs.TEXT_X, yc + 17, 12.5,
                         c["faint"] if state == "locked" else c["soft"], "regular")
    # The trellis bar, painted, and the module card hanging from it.
    bar = g(f'<rect x="-10" y="{bar_y:.1f}" width="{W + 20}" height="13" rx="5" fill="#A87A50"/>', 1, 0.85)
    bar += g(f'<rect x="-10" y="{bar_y + 8:.1f}" width="{W + 20}" height="4" rx="2" fill="#6E4A2E"/>', 3, 0.5)
    for x in (56, W - 56):
        bar += g(f'<path d="M{x},{bar_y + 8:.1f} L{x},{bar_y + 34:.1f}" stroke="#B59468" stroke-width="2.2"/>', 3, 0.9)
    card, _ = vs.module_card(voc, 20, bar_y + 30, W - 40, upto, c, "light")
    body += items + bar + card
    body += vs.nav(dict(c, bg_top="#FBF4E8"), "light") + vs.tab_bar(c, "light")
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
           f'<defs>{filters()}{fade}{paper}</defs>{body}</svg>')
    return render({"mock": svg}, scale)["mock"]
