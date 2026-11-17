#!/usr/bin/env python3
"""App Store screenshots for Ara: real Simulator screenshots in a phone, on brand colours,
with a headline (needs Node with Playwright, which cloud sessions have):

    git clone -b qa-screenshots --depth 1 https://github.com/krfix/Georgian-language-app.git /tmp/shots
    python3 tools/appstore/make_screens.py /tmp/shots

Writes brand/app-store/<n>-<name>.png at 1320 × 2868 (iPhone 6.9-inch, the size App Store
Connect asks for; it scales them down for smaller iPhones) and a contact sheet. The
screens come from the QA run (`-seedDemo`: Ana, the invented demo learner). Every number in
the captions is checked against the content (302 phrases, 11 situations, 13 conversations,
53 lessons, 33 letters, 15 exercise kinds). Artwork: brand/svg (tools/brand/make_brand.py).
"""
import base64
import html
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
FONTS = os.path.join(ROOT, "tools", "brand", "fonts")
SVG = os.path.join(ROOT, "brand", "svg")
OUT = os.path.join(ROOT, "brand", "app-store")
W, H = 1320, 2868

# Each slide: file name, background (two colours), text colour, eyebrow, headline, line
# under it, screens (one, or two for a pair), and extras.
SLIDES = [
    dict(name="hero", bg=("#17AAC6", "#7A3BC2"), mid="#3F73D9", eyebrow="logo",
         title="Learn Georgian.<br>Live Georgian.",
         line="The phrases you need today, and a course from the very first letter.",
         shots=["light-02-home"], mascot="hello"),
    dict(name="show", bg=("#E23B4E", "#8A1F45"), eyebrow="Show to someone",
         title="Just show<br>the driver",
         line="Any phrase full screen, big enough to read from across the counter.",
         shots=["light-07-show-pb-ak-gamicheret-tu-sheidzleba"]),
    dict(name="search", bg=("#1592AD", "#0E5F7A"), eyebrow="Search",
         title="Type what you<br>want to say",
         line="In English, Georgian or Latin letters. Typos are fine.",
         shots=["light-09-search-water"]),
    dict(name="situations", bg=("#FFC045", "#FF8A1F"), ink="#2A1A06", eyebrow="Use in Georgia",
         title="302 phrases<br>for real life",
         line="Taxis, the bazaar, cafés, the pharmacy, the gym. Offline, nothing to unlock.",
         shots=["light-03-phrasebook"]),
    dict(name="listen", bg=("#27964F", "#1588A3"), eyebrow="Listen and repeat",
         title="Hear it.<br>Say it.",
         line="Every phrase spoken aloud, slower if you like, with a guide to each sound.",
         shots=["light-06-phrase-pb-ak-gamicheret-tu-sheidzleba"]),
    dict(name="conversations", bg=("#7A3BC2", "#1588A3"), eyebrow="Conversations",
         title="Practise real<br>conversations",
         line="13 everyday dialogues. Read them, hear them, answer from either side.",
         shots=["light-11-dialogue-pd-bazaar"]),
    dict(name="alphabet", bg=("#E23B4E", "#7A3BC2"), eyebrow="Learn",
         title="Read Georgian<br>from day one",
         line="All 33 letters, one sound each, in short, friendly lessons.",
         shots=["light-15-alphabet"]),
    dict(name="lessons", bg=("#55248F", "#E23B4E"), eyebrow="53 lessons",
         title="Short lessons<br>that stick",
         line="15 kinds of exercise, and reviews timed so you don’t forget.",
         shots=["light-27-ex-v7-multipleChoice", "light-20-review"]),
    dict(name="companion", bg=("#2B1B3D", "#120E18"), eyebrow="logo",
         title="Your Georgia,<br>in your pocket",
         line="Save the phrases you use. Offline, no account, all on your iPhone.",
         shots=["dark-13-saved"], mascot="cheer"),
]


def data_uri(path, mime):
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode()


def font_face(family, file, weight):
    return (f"@font-face{{font-family:'{family}';font-weight:{weight};"
            f"src:url('{data_uri(os.path.join(FONTS, file), 'font/woff2')}') format('woff2');}}")


FONT_CSS = (font_face("Nunito", "Nunito-Bold.woff2", 700) + font_face("Nunito", "Nunito-Black.woff2", 900)
            + font_face("Noto Sans Georgian", "NotoSansGeorgian-ExtraBold.woff2", 800))

# The borjgali (the app's emblem), as in DesignSystem/Components/Borjgali.swift.
def borjgali_path(cx, cy, r):
    import math

    def pt(rad, ang):
        return (cx + math.cos(ang) * rad * r, cy + math.sin(ang) * rad * r)
    d = ""
    for i in range(7):
        a = i / 7 * 2 * math.pi
        s, c1, t, c2, b = pt(0.14, a), pt(1.0, a + 0.25), pt(0.92, a + 1.25), pt(0.62, a + 1.0), pt(0.14, a + 0.62)
        d += f"M{s[0]:.1f},{s[1]:.1f} Q{c1[0]:.1f},{c1[1]:.1f} {t[0]:.1f},{t[1]:.1f} Q{c2[0]:.1f},{c2[1]:.1f} {b[0]:.1f},{b[1]:.1f}Z "
    return d


def phone(src, width, extra_style=""):
    """A phone: a dark bezel with a thin light rim round the real screenshot."""
    return (f'<div class="phone" style="width:{width}px;{extra_style}">'
            f'<img src="{src}" alt=""></div>')


def slide_html(s, shots_dir):
    ink = s.get("ink", "#FFFFFF")
    soft = "rgba(42,26,6,.78)" if s.get("ink") else "rgba(255,255,255,.86)"
    c1, c2 = s["bg"]
    mid = f"{s['mid']} 50%," if s.get("mid") else ""
    shots = [data_uri(os.path.join(shots_dir, n + ".png"), "image/png") for n in s["shots"]]
    if s["eyebrow"] == "logo":
        logo = "ara-logo-horizontal-white" if not s.get("ink") else "ara-logo-horizontal-black"
        eyebrow = f'<img class="logo" src="{data_uri(os.path.join(SVG, "ara-symbol.svg"), "image/svg+xml")}" alt=""><span class="word">Ara</span>'
    else:
        eyebrow = f'<span class="pill">{html.escape(s["eyebrow"])}</span>'
    if len(shots) == 1:
        # Big, and bleeding off the bottom on purpose: more of the app, less empty phone.
        phones = phone(shots[0], 1060, f"left:{(W - 1060) // 2}px;top:800px;")
    else:  # a pair: the second phone behind, to the left and a little lower
        phones = (phone(shots[1], 860, "left:-10px;top:1000px;transform:rotate(-6deg);")
                  + phone(shots[0], 900, "left:400px;top:840px;transform:rotate(4deg);"))
    mascot = ""
    if s.get("mascot"):
        m = data_uri(os.path.join(SVG, f"ara-mascot-{s['mascot']}.svg"), "image/svg+xml")
        mascot = f'<img class="mascot" src="{m}" alt="">'
    deco = (f'<svg class="deco" viewBox="0 0 {W} {H}"><path d="{borjgali_path(1180, 520, 520)}" fill="{ink}" opacity=".07"/>'
            f'<path d="{borjgali_path(80, 2500, 420)}" fill="{ink}" opacity=".05"/></svg>')
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
{FONT_CSS}
*{{box-sizing:border-box;margin:0}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;background:linear-gradient(165deg,{c1} 0%,{mid}{c2} 100%);font-family:Nunito,sans-serif;color:{ink}}}
body::before{{content:"";position:absolute;inset:0;background:radial-gradient(1100px 900px at 20% 6%,rgba(255,255,255,.22),transparent 70%)}}
.deco{{position:absolute;inset:0;width:{W}px;height:{H}px}}
.text{{position:absolute;left:100px;right:100px;top:130px;display:flex;flex-direction:column;gap:28px}}
.eyebrow{{display:flex;align-items:center;gap:22px;height:96px}}
.pill{{font-weight:900;font-size:42px;letter-spacing:.07em;text-transform:uppercase;padding:16px 34px;border-radius:999px;background:{'rgba(42,26,6,.12)' if s.get('ink') else 'rgba(255,255,255,.2)'}}}
.logo{{width:96px;height:96px;background:#FFF7EF;border-radius:26px;padding:10px}}
.word{{font-weight:900;font-size:64px;letter-spacing:-.02em}}
h1{{font-weight:900;font-size:140px;line-height:.98;letter-spacing:-.03em}}
p{{font-weight:700;font-size:50px;line-height:1.26;color:{soft};max-width:{860 if s.get('mascot') else 1100}px}}
.phone{{position:absolute;padding:24px;border-radius:150px;background:#0E0B12;
  box-shadow:0 0 0 5px rgba(255,255,255,.32),0 60px 120px rgba(20,8,30,.45),0 18px 40px rgba(20,8,30,.3)}}
.phone img{{display:block;width:100%;border-radius:126px}}
.mascot{{position:absolute;right:28px;top:{'520' if s['name']=='hero' else '500'}px;height:{'400' if s['name']=='hero' else '420'}px;filter:drop-shadow(0 24px 30px rgba(20,8,30,.35))}}
</style></head><body>{deco}
<div class="text"><div class="eyebrow">{eyebrow}</div><h1>{s['title']}</h1><p>{html.escape(s['line'])}</p></div>
{phones}{mascot}
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


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    shots = os.path.abspath(sys.argv[1])
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    for i, s in enumerate(SLIDES, 1):
        with open(os.path.join(tmp, f"{i:02d}-{s['name']}.html"), "w") as f:
            f.write(slide_html(s, shots))
    js = os.path.join(tmp, "render.js")
    with open(js, "w") as f:
        f.write(RENDER_JS)
    subprocess.run(["node", js, tmp, OUT], check=True)
    # The contact sheet: all of them side by side, as on the App Store page.
    from PIL import Image
    files = sorted(f for f in os.listdir(OUT) if f[:2].isdigit() and f.endswith(".png"))
    tw = 330
    sheet = Image.new("RGB", (len(files) * (tw + 24) + 24, int(H * tw / W) + 48), "#F2F2F7")
    for i, f in enumerate(files):
        path = os.path.join(OUT, f)
        Image.open(path).convert("RGB").save(path)   # App Store Connect refuses an alpha channel
        im = Image.open(path).resize((tw, int(H * tw / W)), Image.LANCZOS)
        sheet.paste(im, (24 + i * (tw + 24), 24))
    sheet.save(os.path.join(OUT, "contact-sheet.jpg"), quality=88)
    print(f"{len(files)} screens in brand/app-store")


if __name__ == "__main__":
    main()
