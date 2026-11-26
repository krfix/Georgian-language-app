#!/usr/bin/env python3
"""App Store screenshots for Ara (KART #6 redesign): real Simulator screenshots in a phone,
on brand colours, with a headline, a callout (a piece of the screen lifted out and
enlarged, so it reads at thumbnail size) and one ribbon that runs through every slide, so
the set reads as one strip when swiped. Needs Node with Playwright (cloud sessions have it):

    git clone -b qa-screenshots --depth 1 https://github.com/krfix/Georgian-language-app.git /tmp/shots
    python3 tools/appstore/make_screens.py /tmp/shots

Writes brand/app-store/en/<n>-<name>.png and brand/app-store/pl/… at 1320 × 2868 (iPhone
6.9-inch, the size App Store Connect asks for; it scales them for smaller iPhones), and a
contact sheet for each. The screens come from the QA run (`-seedDemo`: Lena (Ana before KART #16), the invented
demo learner). Every number is checked against the content when the script runs (phrases,
situations, conversations, lessons, letters). Artwork: brand/svg (tools/brand/make_brand.py).
"""
import base64
import html
import json
import math
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
FONTS = os.path.join(ROOT, "tools", "brand", "fonts")
SVG = os.path.join(ROOT, "brand", "svg")
OUT = os.path.join(ROOT, "brand", "app-store")
CUR = os.path.join(ROOT, "Georgian", "Resources", "Curriculum")
W, H = 1320, 2868
SHOT_W, SHOT_H = 1206, 2622          # the Simulator's screenshots (iPhone, 3x)


def counts():
    course = json.load(open(os.path.join(CUR, "course.json")))
    pb = json.load(open(os.path.join(CUR, "phrasebook.json")))
    letters = json.load(open(os.path.join(CUR, "letters.json")))
    return dict(lessons=sum(len(m["lessons"]) for m in course["modules"]), phrases=len(pb["phrases"]),
                situations=len(pb["categories"]), conversations=len(pb["dialogues"]),
                letters=len(letters["letters"]))


N = counts()
assert N["letters"] == 33, N

# Callouts: (x0, y0, x1, y1) in the screenshot's pixels, measured on the QA screenshots.
LEVEL_CARD = (55, 690, 1150, 1050)
ROAD = (50, 1020, 1156, 1385)

# Each slide: name, background (two colours, an optional middle), dark text for light
# backgrounds, eyebrow ("logo" for the wordmark), headline (<em> = highlighted), line,
# screens (one, or two for a pair), layout, callout, mascot.
EN = [
    dict(name="hero", bg=("#17AAC6", "#3F73D9", "#7A3BC2"), eyebrow="logo",
         title="Learn Georgian.<br><em>Live</em> Georgian.",
         line="The phrases you need today, and a course from the very first letter.",
         shots=["dark-02-home"], mascot="hello",
         callout=dict(crop=LEVEL_CARD, zoom=1.2, rotate=-2.5, dy=30)),
    dict(name="show", bg=("#F05A5A", "#E23B4E", "#8A1F45"), eyebrow="Show to someone",
         title="Just show<br><em>the driver</em>",
         line="Any phrase full screen, big enough to read from across the counter.",
         shots=["light-07-show-pb-ak-gamicheret-tu-sheidzleba"], layout="tilt",
         chips=["🚕 Taxi", "☕ Café", "💊 Pharmacy"]),
    dict(name="search", bg=("#1BB3CF", "#1592AD", "#0E5F7A"), eyebrow="Search",
         title="Type what you<br><em>want to say</em>",
         line="English, Georgian or Latin letters. Typos are fine.",
         shots=["light-09-search-water"],
         callout=dict(crop=(60, 808, 1150, 1012), zoom=1.2, rotate=2)),
    dict(name="situations", bg=("#FFD36B", "#FFC045", "#FF8A1F"), ink="#2A1A06", eyebrow="Use in Georgia",
         title=f"<em>{N['phrases']}</em> phrases<br>for real life",
         line=f"{N['situations']} situations: taxis, the bazaar, cafés, the pharmacy. Offline, nothing to unlock.",
         shots=["light-03-phrasebook"],
         callout=dict(crop=(60, 815, 1150, 1060), zoom=1.2, rotate=-2)),
    dict(name="listen", bg=("#34B36A", "#27964F", "#1588A3"), eyebrow="Listen and repeat",
         title="Hear it.<br><em>Say it.</em>",
         line="Every phrase spoken aloud, slower if you like, with a guide to each sound.",
         shots=["light-06-phrase-pb-ak-gamicheret-tu-sheidzleba"],
         callout=dict(crop=(50, 1840, 1156, 2160), zoom=1.18, rotate=1.5)),
    dict(name="conversations", bg=("#9257D6", "#7A3BC2", "#1588A3"), eyebrow="Conversations",
         title="Practise real<br><em>conversations</em>",
         line=f"{N['conversations']} everyday dialogues. Read them, hear them, answer from either side.",
         shots=["light-11-dialogue-pd-bazaar"],
         callout=dict(crop=(455, 1262, 1180, 1575), zoom=1.3, rotate=3, dx=-60)),
    dict(name="levels", bg=("#7A3BC2", "#B8378F", "#FF8A1F"), eyebrow="Your journey",
         title="From <em>Just landed</em><br>to Tamada",
         line="Six stages, each with what you can do: read signs, shop at the bazaar, join a supra.",
         shots=["light-21-progress"],
         callout=dict(crop=ROAD, zoom=1.18, rotate=-1.5)),
    dict(name="alphabet", bg=("#F05A5A", "#E23B4E", "#7A3BC2"), eyebrow="Learn",
         title="Read Georgian<br><em>from day one</em>",
         line=f"All {N['letters']} letters, one sound each, in short, friendly lessons.",
         shots=["light-15-alphabet"], layout="tilt"),
    dict(name="lessons", bg=("#6B2FB0", "#55248F", "#E23B4E"), eyebrow=f"{N['lessons']} lessons",
         title="Short lessons<br><em>that stick</em>",
         line="15 kinds of exercise, and reviews timed so you don’t forget.",
         shots=["light-27-ex-v7-multipleChoice", "light-20-review"], layout="pair"),
    dict(name="companion", bg=("#3A2552", "#2B1B3D", "#120E18"), eyebrow="logo",
         title="Your Georgia,<br><em>in your pocket</em>",
         line="Save the phrases you use. Offline, no account, all on your iPhone.",
         shots=["dark-13-saved"], mascot="cheer"),
]

PL = [
    dict(EN[0], title="Gruziński<br><em>na co dzień</em>",
         line="Zwroty potrzebne dziś i kurs od pierwszej litery.", shots=["polish-home"],
         callout=dict(crop=(55, 680, 1150, 1010), zoom=1.2, rotate=-2.5, dy=30)),
    dict(EN[2], eyebrow="Szukaj", title="Wpisz, co chcesz<br><em>powiedzieć</em>",
         line="Po polsku, po gruzińsku albo łacinką. Literówki nie szkodzą.",
         shots=["polish-search-apteka"], callout=None),
    dict(EN[3], eyebrow="W Gruzji", title=f"<em>{N['phrases']}</em> zwroty<br>na co dzień",
         line=f"{N['situations']} sytuacji: taksówka, bazar, kawiarnia, apteka. Offline, nic do odblokowania.",
         shots=["polish-phrasebook"], callout=None),
    dict(EN[4], eyebrow="Słuchaj i powtarzaj", title="Usłysz.<br><em>Powiedz.</em>",
         line="Każdy zwrot do odsłuchania, także wolniej, z przewodnikiem po każdym dźwięku.",
         shots=["polish-phrase-pb-ak-gamicheret-tu-sheidzleba"], callout=None),
    dict(EN[5], eyebrow="Rozmowy", title="Ćwicz prawdziwe<br><em>rozmowy</em>",
         line=f"{N['conversations']} codziennych dialogów. Czytaj, słuchaj, odpowiadaj za każdą ze stron.",
         shots=["polish-dialogue-pd-bazaar"], callout=None),
    dict(EN[6], eyebrow="Twoja droga", title="Od <em>lądowania</em><br>do tamady",
         line="Sześć etapów, każdy z tym, co już umiesz: szyldy, bazar, supra.",
         shots=["polish-progress"], callout=None),
    dict(EN[8], eyebrow=f"{N['lessons']} lekcji", title="Krótkie lekcje,<br><em>które zostają</em>",
         line="15 rodzajów ćwiczeń i powtórki we właściwym momencie.",
         shots=["polish-ex-v7-multipleChoice", "polish-review"]),
]


def data_uri(path, mime):
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()


def font_face(family, file, weight):
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};"
            f"src:url('{data_uri(os.path.join(FONTS, file), 'font/woff2')}') format('woff2');}}")


FONT_CSS = (font_face("Nunito", "Nunito-Bold.woff2", 700) + font_face("Nunito", "Nunito-Black.woff2", 900)
            + font_face("Noto Sans Georgian", "NotoSansGeorgian-ExtraBold.woff2", 800))


def borjgali_path(cx, cy, r):
    """The borjgali (the app's emblem), as in DesignSystem/Components/Borjgali.swift."""
    def pt(rad, ang):
        return (cx + math.cos(ang) * rad * r, cy + math.sin(ang) * rad * r)
    d = ""
    for i in range(7):
        a = i / 7 * 2 * math.pi
        s, c1, t, c2, b = pt(0.14, a), pt(1.0, a + 0.25), pt(0.92, a + 1.25), pt(0.62, a + 1.0), pt(0.14, a + 0.62)
        d += f"M{s[0]:.1f},{s[1]:.1f} Q{c1[0]:.1f},{c1[1]:.1f} {t[0]:.1f},{t[1]:.1f} Q{c2[0]:.1f},{c2[1]:.1f} {b[0]:.1f},{b[1]:.1f}Z "
    return d


def ribbon_path(n):
    """One wave across all n slides, drawn in the strip's coordinates (slide i is x from
    i·W to (i+1)·W): each slide shows its own piece, so the wave carries on when swiped."""
    pts = []
    for k in range(n * 4 + 1):
        x = k * W / 4
        y = 700 + 360 * math.sin(k * 0.9) + 140 * math.sin(k * 0.37 + 1)
        pts.append((x, y))
    d = f"M{pts[0][0]:.0f},{pts[0][1]:.0f}"
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        mx = (x0 + x1) / 2
        d += f" C{mx:.0f},{y0:.0f} {mx:.0f},{y1:.0f} {x1:.0f},{y1:.0f}"
    return d


def phone(src, width, style):
    """A phone: a near-black bezel with a thin light rim round the real screenshot."""
    return f'<div class="phone" style="width:{width}px;{style}"><img src="{src}" alt=""></div>'


def callout_html(src, c, phone_left, phone_top, phone_w):
    """A piece of the screen lifted out of the phone where it sits, enlarged (zoom) and
    tilted, so it reads at thumbnail size and plainly belongs to the screen below."""
    x0, y0, x1, y1 = c["crop"]
    s = (phone_w - 44) / SHOT_W            # the screenshot's scale inside the phone
    scale = s * c.get("zoom", 1.2)
    w, h = (x1 - x0) * scale, (y1 - y0) * scale
    cx = phone_left + 22 + (x0 + x1) / 2 * s + c.get("dx", 0)
    cy = phone_top + 22 + (y0 + y1) / 2 * s + c.get("dy", 0)
    left = min(max(cx - w / 2, 36), W - 36 - w)
    return (f'<div class="callout" style="left:{left:.0f}px;top:{cy - h / 2:.0f}px;width:{w:.0f}px;height:{h:.0f}px;'
            f'transform:rotate({c["rotate"]}deg);background-image:url({src});'
            f'background-size:{SHOT_W * scale:.0f}px {SHOT_H * scale:.0f}px;'
            f'background-position:{-x0 * scale:.0f}px {-y0 * scale:.0f}px"></div>')


def slide_html(s, i, n, shots_dir, ribbon):
    ink = s.get("ink", "#FFFFFF")
    dark_ink = bool(s.get("ink"))
    soft = "rgba(42,26,6,.8)" if dark_ink else "rgba(255,255,255,.9)"
    accent = "#8A1F45" if dark_ink else "#FFD36B"
    c1, c2, c3 = s["bg"]
    shots = [data_uri(os.path.join(shots_dir, name + ".png"), "image/png") for name in s["shots"]]
    if s["eyebrow"] == "logo":
        eyebrow = (f'<img class="logo" src="{data_uri(os.path.join(SVG, "ara-symbol.svg"), "image/svg+xml")}" alt="">'
                   f'<span class="word">Ara</span>')
    else:
        eyebrow = f'<span class="pill">{html.escape(s["eyebrow"])}</span>'
    layout = s.get("layout", "top")
    if layout == "pair":   # the second phone behind, to the left and a little lower
        phones = (phone(shots[1], 800, "left:30px;top:1080px;transform:rotate(-7deg);")
                  + phone(shots[0], 860, "left:480px;top:880px;transform:rotate(4deg);"))
    elif layout == "tilt":  # one phone, turned a little, for screens that are a picture
        phones = phone(shots[0], 1010, f"left:{(W - 1010) // 2 + 30}px;top:860px;transform:rotate(3.5deg);")
    else:                   # big, and bleeding off the bottom: more app, less empty phone
        phones = phone(shots[0], 1060, f"left:{(W - 1060) // 2}px;top:800px;")
    call = callout_html(shots[0], s["callout"], (W - 1060) // 2, 800, 1060) if s.get("callout") else ""
    chips = ""
    if s.get("chips"):
        spots = [(24, 1210, -6), (24, 1940, 5), (800, 2380, -4)]   # beside the text, never on it
        chips = "".join(f'<div class="chip" style="left:{x}px;top:{y}px;transform:rotate({r}deg)">{html.escape(t)}</div>'
                        for t, (x, y, r) in zip(s["chips"], spots))
    mascot = ""
    if s.get("mascot"):
        m = data_uri(os.path.join(SVG, f"ara-mascot-{s['mascot']}.svg"), "image/svg+xml")
        mascot = f'<img class="mascot" src="{m}" alt="">'
    # The ribbon (one wave through the whole strip) and a borjgali sitting on each seam,
    # half on this slide and half on the next.
    deco = (f'<svg class="deco" viewBox="{i * W} 0 {W} {H}" preserveAspectRatio="none">'
            f'<path d="{ribbon}" stroke="{ink}" stroke-opacity=".13" stroke-width="150" fill="none" stroke-linecap="round"/>'
            f'<path d="{ribbon}" stroke="{ink}" stroke-opacity=".18" stroke-width="6" fill="none" transform="translate(0,120)"/>'
            + "".join(f'<path d="{borjgali_path(k * W, 2560 if k % 2 else 380, 300)}" fill="{ink}" opacity=".08"/>'
                      for k in range(n + 1))
            + "</svg>")
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
{FONT_CSS}
*{{box-sizing:border-box;margin:0}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;background:linear-gradient(160deg,{c1} 0%,{c2} 45%,{c3} 100%);font-family:Nunito,'Noto Sans Georgian',sans-serif;color:{ink}}}
body::before{{content:"";position:absolute;inset:0;background:radial-gradient(1200px 900px at 15% 4%,rgba(255,255,255,.26),transparent 70%)}}
body::after{{content:"";position:absolute;left:0;right:0;bottom:0;height:900px;background:linear-gradient(to top,rgba(20,8,30,.22),transparent)}}
.deco{{position:absolute;inset:0;width:{W}px;height:{H}px}}
.text{{position:absolute;left:96px;right:96px;top:120px;display:flex;flex-direction:column;gap:26px;z-index:3}}
.eyebrow{{display:flex;align-items:center;gap:22px;height:96px}}
.pill{{font-weight:900;font-size:40px;letter-spacing:.08em;text-transform:uppercase;padding:16px 34px;border-radius:999px;
  background:{'rgba(42,26,6,.12)' if dark_ink else 'rgba(255,255,255,.22)'};border:2px solid {'rgba(42,26,6,.14)' if dark_ink else 'rgba(255,255,255,.35)'}}}
.logo{{width:96px;height:96px;background:#FFF7EF;border-radius:26px;padding:10px;box-shadow:0 10px 24px rgba(20,8,30,.25)}}
.word{{font-weight:900;font-size:66px;letter-spacing:-.02em}}
h1{{font-weight:900;font-size:136px;line-height:.98;letter-spacing:-.035em;text-shadow:0 4px 24px rgba(20,8,30,{'0' if dark_ink else '.18'})}}
h1 em{{font-style:normal;color:{accent};position:relative;white-space:nowrap}}
p{{font-weight:700;font-size:48px;line-height:1.28;color:{soft};max-width:{860 if s.get('mascot') else 1100}px}}
.phone{{position:absolute;padding:22px;border-radius:148px;background:#0E0B12;z-index:1;
  box-shadow:0 0 0 5px rgba(255,255,255,.34),0 70px 140px rgba(20,8,30,.5),0 20px 44px rgba(20,8,30,.32)}}
.phone img{{display:block;width:100%;border-radius:126px}}
.callout{{position:absolute;z-index:2;border-radius:52px;background-repeat:no-repeat;
  box-shadow:0 0 0 7px #FFFFFF,0 50px 90px rgba(20,8,30,.45),0 14px 30px rgba(20,8,30,.3)}}
.chip{{position:absolute;z-index:2;white-space:nowrap;font-weight:900;font-size:54px;padding:22px 40px;border-radius:999px;background:#FFFFFF;color:#2A1A2E;
  box-shadow:0 30px 60px rgba(20,8,30,.35)}}
.mascot{{position:absolute;right:30px;top:{'500' if s['name']=='hero' else '470'}px;height:{'410' if s['name']=='hero' else '430'}px;z-index:3;
  filter:drop-shadow(0 24px 30px rgba(20,8,30,.35))}}
</style></head><body>{deco}
<div class="text"><div class="eyebrow">{eyebrow}</div><h1>{s['title']}</h1><p>{html.escape(s['line'])}</p></div>
{phones}{call}{chips}{mascot}
</body></html>"""


RENDER_JS = r"""
const {chromium} = require('playwright');
(async () => {
  const [dir, out] = process.argv.slice(2);
  const fs = require('fs');
  const b = await chromium.launch();
  const p = await b.newPage({viewport: {width: %d, height: %d}, deviceScaleFactor: 1});
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.html')).sort()) {
    await p.goto('file://' + dir + '/' + f);
    await p.evaluate(() => document.fonts.ready);
    await p.waitForTimeout(150);
    await p.screenshot({path: out + '/' + f.replace('.html', '.png')});
  }
  await b.close();
})();
""" % (W, H)


def render(slides, shots, out):
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith((".png", ".jpg")):
            os.remove(os.path.join(out, f))
    tmp = tempfile.mkdtemp()
    ribbon = ribbon_path(len(slides))
    for i, s in enumerate(slides):
        with open(os.path.join(tmp, f"{i + 1:02d}-{s['name']}.html"), "w") as f:
            f.write(slide_html(s, i, len(slides), shots, ribbon))
    js = os.path.join(tmp, "render.js")
    with open(js, "w") as f:
        f.write(RENDER_JS)
    subprocess.run(["node", js, tmp, out], check=True)
    # The contact sheet: all of them side by side and touching, as when swiped, so the
    # ribbon can be checked across the seams.
    from PIL import Image
    files = sorted(f for f in os.listdir(out) if f[:2].isdigit() and f.endswith(".png"))
    tw = 330
    th = int(H * tw / W)
    sheet = Image.new("RGB", (len(files) * tw + 48, th + 48), "#F2F2F7")
    for i, f in enumerate(files):
        path = os.path.join(out, f)
        Image.open(path).convert("RGB").save(path)   # App Store Connect refuses an alpha channel
        sheet.paste(Image.open(path).resize((tw, th), Image.LANCZOS), (24 + i * tw, 24))
    sheet.save(os.path.join(out, "contact-sheet.jpg"), quality=88)
    print(f"{len(files)} screens in {os.path.relpath(out, ROOT)}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    shots = os.path.abspath(sys.argv[1])
    render(EN, shots, os.path.join(OUT, "en"))
    render(PL, shots, os.path.join(OUT, "pl"))


if __name__ == "__main__":
    main()
