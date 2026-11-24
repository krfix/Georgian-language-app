#!/usr/bin/env python3
"""Draws the whole Ara identity from tools/brand/ara.py (needs cairosvg, fonttools, Pillow):

    pip install cairosvg fonttools pillow
    python3 tools/brand/make_brand.py

Writes
- brand/          the vector masters (SVG) and previews (PNG) of the symbol, logos, app icon
                  and mascot, for anything outside the app (App Store, website, print);
- Georgian/Assets.xcassets
                  AppIcon (light, dark and tinted), AraSymbol (vector PDF), LaunchMark (PNG)
                  and the mascot poses Parrot, ParrotBlink, ParrotCheer, ParrotThink and
                  ParrotSleep (vector PDF);
- web/icons/      the web app's home-screen and browser-tab icons and three mascot poses
                  (alone: python3 tools/brand/make_brand.py --web);
- brand/vine/     with --vine only: the grapevine Learn path's parts and still mock-ups of
                  the screen (tools/brand/vine.py, vine_screens.py; docs/vine-path.md).
                  Also needs brotli (pip install brotli) to read the Nunito Bold font.
The wordmark is Nunito Black (SIL Open Font License, tools/brand/fonts/OFL-Nunito.txt), turned into
outlines, so no font is needed to show it. docs/brand.md explains how to use it all.
"""
import io
import json
import os
import sys

import cairosvg
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ara  # noqa: E402
from ara import Space  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
BRAND = os.path.join(ROOT, "brand")
ASSETS = os.path.join(ROOT, "Georgian", "Assets.xcassets")
FONT = os.path.join(HERE, "fonts", "Nunito-Black.ttf")
TAGLINE = "Learn Georgian. Live Georgian."


# ---------------------------------------------------------------------------------------
# Helpers

def doc(w, h, body, defs="", bg=None):
    rect = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{defs}</defs>{rect}{body}</svg>\n')


def png(svg, width):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=width))).convert("RGBA")


def ink_box(body, w=1200, h=1200):
    """The bounding box of what a drawing actually paints, in its own units."""
    im = png(doc(w, h, body), w)
    return im.getbbox()


def write(path, data, mode="w"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, mode) as f:
        f.write(data)


def unit_box(draw):
    """The ink box of a unit-space drawing, in unit space (drawn with R=150 around (800,500)
    on a 1600-unit canvas: room for the mascot's tail)."""
    x0, y0, x1, y1 = ink_box(draw(Space(800, 500, 150)), 1600, 1600)
    return ((x0 - 800) / 150, (y0 - 500) / 150, (x1 - 800) / 150, (y1 - 500) / 150)


def fit(box, cx, cy, size):
    """Head centre and radius that put a unit-space box of the given size centred on (cx, cy)."""
    x0, y0, x1, y1 = box
    R = size / max(x1 - x0, y1 - y0)
    return cx - (x0 + x1) / 2 * R, cy - (y0 + y1) / 2 * R, R


def symbol(sp, mono=None, **kw):
    if mono:
        main, beak = ara.symbol_mono_d(sp)
        return f'<path d="{main}" fill="{mono}" fill-rule="evenodd"/><path d="{beak}" fill="{mono}"/>'
    return ara.head_svg(sp, **kw)


SYM_BOX = unit_box(lambda sp: symbol(Space(sp.cx, sp.cy, sp.R, ara.HEAD_TILT)))


def placed_symbol(cx, cy, size, **kw):
    hx, hy, R = fit(SYM_BOX, cx, cy, size)
    return symbol(Space(hx, hy, R, ara.HEAD_TILT), **kw)


def wordmark_d(text, x, baseline, cap, tracking=-0.055):
    """Outlines of `text` in Nunito Black with its capitals `cap` units tall; returns the
    path data and the width."""
    f = TTFont(FONT)
    gs, cmap, hm = f.getGlyphSet(), f.getBestCmap(), f["hmtx"]
    s = cap / f["OS/2"].sCapHeight
    d, start = [], x
    for ch in text:
        if ch == " ":
            x += hm[cmap[32]][0] * s
            continue
        g = cmap[ord(ch)]
        p = SVGPathPen(gs)
        gs[g].draw(TransformPen(p, (s, 0, 0, -s, x, baseline)))
        d.append(p.getCommands())
        x += hm[g][0] * s + tracking * cap * 1.4
    return " ".join(d), x - start - tracking * cap * 1.4


# ---------------------------------------------------------------------------------------
# App icon

def icon(kind="light"):
    S = 1024
    if kind == "light":
        defs = (f'<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#17AAC6"/>'
                '<stop offset="0.5" stop-color="#3F73D9"/>'
                f'<stop offset="1" stop-color="{ara.SAPERAVI}"/></linearGradient>'
                '<radialGradient id="glow" cx="0.3" cy="0.22" r="0.75"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.16"/>'
                '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>')
        bg = '<rect width="1024" height="1024" fill="url(#bg)"/><rect width="1024" height="1024" fill="url(#glow)"/>'
        mark = placed_symbol(S / 2, S / 2 + 6, S * 0.64, collar_colors=[ara.GOLD, ara.MACAW_DEEP])
    elif kind == "dark":
        defs = (f'<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{ara.NIGHT_RAISED}"/>'
                f'<stop offset="1" stop-color="{ara.NIGHT}"/></linearGradient>')
        bg = '<rect width="1024" height="1024" fill="url(#bg)"/>'
        mark = placed_symbol(S / 2, S / 2 + 6, S * 0.64, collar_colors=[ara.GOLD, "#3C86F0"])
    else:  # tinted: grey on black; the iPhone colours it with the user's tint
        defs = ""
        bg = '<rect width="1024" height="1024" fill="#000000"/>'
        hx, hy, R = fit(SYM_BOX, S / 2, S / 2 + 6, S * 0.64)
        mark = ara.head_svg(Space(hx, hy, R, ara.HEAD_TILT), head="#FFFFFF", beak="#9A9A9A",
                            collar_colors=["#C8C8C8", "#7A7A7A"])
        mark = mark.replace(ara.PAPER, "#000000").replace(ara.BEAK_SHADE, "#3A3A3A")
        mark = mark.replace(f'fill="{ara.INK}"', 'fill="#000000"')  # the eye: a black dot with its light
    return doc(S, S, bg + mark, defs)


# ---------------------------------------------------------------------------------------
# Logos

def lockup(kind="horizontal", theme="light", mono=None, tagline=False):
    ink = mono or (ara.INK if theme == "light" else ara.PAPER)
    cap = 200
    if kind == "horizontal":
        sym = 300
        d, w = wordmark_d("Ara", 0, 0, cap)
        gap = 70
        W, H = sym + gap + w + 80, sym + 80
        sx = 40 + sym / 2
        body = placed_symbol(sx, H / 2, sym, mono=mono)
        tx = 40 + sym + gap
        d, _ = wordmark_d("Ara", tx, H / 2 + cap / 2, cap)
        body += f'<path d="{d}" fill="{ink}"/>'
        if tagline:
            t, tw = wordmark_d(TAGLINE, tx + 6, H / 2 + cap / 2 + 90, 44, tracking=0.0)
            body += f'<path d="{t}" fill="{mono or (ara.POMEGRANATE if theme == "light" else "#FF5D6E")}"/>'
            W = max(W, tx + tw + 60)
            H += 60
    else:  # stacked
        sym = 420
        d, w = wordmark_d("Ara", 0, 0, cap)
        t, tw = wordmark_d(TAGLINE, 0, 0, 46, tracking=0.0)
        W = max(sym, w, tw if tagline else 0) + 160
        H = 60 + sym + 60 + cap + (110 if tagline else 0) + 60
        body = placed_symbol(W / 2, 60 + sym / 2, sym, mono=mono)
        d, _ = wordmark_d("Ara", (W - w) / 2, 60 + sym + 60 + cap, cap)
        body += f'<path d="{d}" fill="{ink}"/>'
        if tagline:
            t, _ = wordmark_d(TAGLINE, (W - tw) / 2, 60 + sym + 60 + cap + 100, 46, tracking=0.0)
            body += f'<path d="{t}" fill="{mono or (ara.POMEGRANATE if theme == "light" else "#FF5D6E")}"/>'
    bg = None if mono else (ara.PAPER if theme == "light" else ara.NIGHT)
    return doc(round(W), round(H), body, bg=bg)


def symbol_doc(mono=None, size=1024, bg=None):
    return doc(size, size, placed_symbol(size / 2, size / 2, size * 0.86, mono=mono), bg=bg)


# ---------------------------------------------------------------------------------------
# Mascot: every pose on the same canvas, so switching poses never makes Ara jump

def mascot_canvas():
    boxes = [unit_box(lambda sp, p=p: ara.mascot_svg(sp.cx, sp.cy, sp.R, p)) for p in ara.POSES]
    x0 = min(b[0] for b in boxes) - 0.06
    y0 = min(b[1] for b in boxes) - 0.06
    x1 = max(b[2] for b in boxes) + 0.06
    y1 = max(b[3] for b in boxes) + 0.06
    R = 100
    return (x1 - x0) * R, (y1 - y0) * R, -x0 * R, -y0 * R, R


def mascot_doc(pose):
    W, H, cx, cy, R = mascot_canvas()
    return doc(round(W), round(H), ara.mascot_svg(cx, cy, R, pose))


# ---------------------------------------------------------------------------------------
# Xcode assets

def imageset(name, pdf_svg, note):
    folder = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        os.remove(os.path.join(folder, f))
    fn = name[0].lower() + name[1:] + ".pdf"
    # (The PDF library's output differs a little between runs even for the same drawing.)
    cairosvg.svg2pdf(bytestring=pdf_svg.encode(), write_to=os.path.join(folder, fn))
    write(os.path.join(folder, "Contents.json"), json.dumps({
        "images": [{"filename": fn, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "original"},
    }, indent=2) + "\n")


def app_icon():
    folder = os.path.join(ASSETS, "AppIcon.appiconset")
    for f in os.listdir(folder):
        os.remove(os.path.join(folder, f))
    images = []
    for kind, fn, look in (("light", "icon-1024.png", None), ("dark", "icon-dark-1024.png", "dark"),
                           ("tinted", "icon-tinted-1024.png", "tinted")):
        png(icon(kind), 1024).convert("RGB").save(os.path.join(folder, fn))
        entry = {"filename": fn, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if look:
            entry = {"appearances": [{"appearance": "luminosity", "value": look}], **entry}
        images.append(entry)
    write(os.path.join(folder, "Contents.json"), json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def launch_mark():
    """The symbol alone, 120 points wide, on the launch screen's paper (or night) colour."""
    folder = os.path.join(ASSETS, "LaunchMark.imageset")
    for f in os.listdir(folder):
        os.remove(os.path.join(folder, f))
    files = []
    for scale in (1, 2, 3):
        fn = f"launch@{scale}x.png"
        png(symbol_doc(size=120), 120 * scale).save(os.path.join(folder, fn))
        files.append({"filename": fn, "idiom": "universal", "scale": f"{scale}x"})
    write(os.path.join(folder, "Contents.json"), json.dumps({"images": files, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def web_icons():
    """The web app's icons (web/icons/): home-screen icons in the app icon's look, a
    full-bleed one for Android's masks, and the symbol as the browser-tab icon."""
    folder = os.path.join(ROOT, "web", "icons")
    os.makedirs(folder, exist_ok=True)
    big = png(icon("light"), 1024)
    big.convert("RGB").resize((180, 180), Image.LANCZOS).save(os.path.join(folder, "apple-touch-icon.png"))
    for w in (192, 512):
        rounded(big.resize((w, w), Image.LANCZOS)).save(os.path.join(folder, f"icon-{w}.png"))
    big.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(folder, "maskable-512.png"))
    png(symbol_doc(size=64), 64).save(os.path.join(folder, "favicon-64.png"))
    write(os.path.join(folder, "favicon.svg"), symbol_doc(size=64))
    write(os.path.join(folder, "mascot-hello.svg"), mascot_doc("hello"))
    write(os.path.join(folder, "mascot-think.svg"), mascot_doc("think"))
    write(os.path.join(folder, "mascot-cheer.svg"), mascot_doc("cheer"))


# ---------------------------------------------------------------------------------------
# Previews

def rounded(im, radius=0.2237):
    w = im.width
    m = Image.new("L", (w * 4, w * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * 4 - 1, w * 4 - 1), radius=int(w * 4 * radius), fill=255)
    out = im.copy()
    out.putalpha(m.resize((w, w), Image.LANCZOS))
    return out


def icon_sizes_preview():
    """The three icons at App Store, home-screen and Settings sizes on light and dark."""
    kinds = ("light", "dark", "tinted")
    big = {k: png(icon(k), 1024) for k in kinds}
    out = Image.new("RGB", (2620, 760), "#F2F2F7")
    ImageDraw.Draw(out).rectangle((0, 380, 2620, 760), fill="#1C1C1E")
    for row, y in ((0, 40), (1, 420)):
        x = 40
        for k in kinds:
            for w in (300, 180, 120, 87, 58):
                im = rounded(big[k].resize((w, w), Image.LANCZOS))
                out.paste(im, (x, y + (300 - w) // 2), im)
                x += w + 18
            x += 20
    return out


def vine_pictures():
    """The grapevine Learn path (KART #15): parts sheet (SVG and PNG), and PNGs of the Learn
    screen, the top of the vine and Ara's hop (the screens at 3x, an iPhone's pixels)."""
    import vine_screens
    folder = os.path.join(BRAND, "vine")
    os.makedirs(folder, exist_ok=True)
    for name, svg in vine_screens.all_mockups().items():
        if "parts" in name:          # the screens' SVGs are mostly text outlines: PNG only
            write(os.path.join(folder, f"{name}.svg"), svg)
        w = float(svg.split('width="', 1)[1].split('"', 1)[0])
        png(svg, int(w * (3 if "learn" in name or "top" in name else 2))).convert("RGB").save(os.path.join(folder, f"{name}.png"))


def main():
    if "--vine" in sys.argv:
        vine_pictures()
        print("grapevine pictures in brand/vine/")
        return
    if "--web" in sys.argv:
        web_icons()
        print("web icons in web/icons/")
        return
    os.makedirs(os.path.join(BRAND, "svg"), exist_ok=True)
    os.makedirs(os.path.join(BRAND, "png"), exist_ok=True)
    masters = {
        "ara-symbol": symbol_doc(),
        "ara-symbol-black": symbol_doc(mono="#000000"),
        "ara-symbol-white": symbol_doc(mono="#FFFFFF"),
        "ara-app-icon": icon("light"),
        "ara-app-icon-dark": icon("dark"),
        "ara-app-icon-tinted": icon("tinted"),
        "ara-logo-horizontal": lockup("horizontal", "light"),
        "ara-logo-horizontal-dark": lockup("horizontal", "dark"),
        "ara-logo-horizontal-black": lockup("horizontal", mono="#000000"),
        "ara-logo-horizontal-white": lockup("horizontal", mono="#FFFFFF"),
        "ara-logo-horizontal-tagline": lockup("horizontal", "light", tagline=True),
        "ara-logo-stacked": lockup("stacked", "light", tagline=True),
        "ara-logo-stacked-dark": lockup("stacked", "dark", tagline=True),
    }
    for pose in ara.POSES:
        masters[f"ara-mascot-{pose}"] = mascot_doc(pose)
    for name, svg in masters.items():
        write(os.path.join(BRAND, "svg", f"{name}.svg"), svg)
        w = 1024 if "icon" in name or "symbol" in name else 1200
        im = png(svg, w)
        if name.endswith("-white"):
            bgim = Image.new("RGBA", im.size, ara.NIGHT)
            bgim.alpha_composite(im)
            im = bgim
        im.save(os.path.join(BRAND, "png", f"{name}.png"))
    icon_sizes_preview().save(os.path.join(BRAND, "png", "ara-app-icon-sizes.png"))

    app_icon()
    launch_mark()
    imageset("AraSymbol", symbol_doc(size=200), "the symbol")
    names = {"hello": "Parrot", "blink": "ParrotBlink", "cheer": "ParrotCheer", "think": "ParrotThink", "sleep": "ParrotSleep"}
    for pose, name in names.items():
        imageset(name, mascot_doc(pose), pose)
    web_icons()
    print(f"{len(masters)} masters in brand/, app icon, launch mark, symbol and {len(names)} mascot poses in the asset catalog")


if __name__ == "__main__":
    main()
