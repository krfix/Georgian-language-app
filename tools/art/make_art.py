#!/usr/bin/env python3
"""Draws the app icon and the launch mark (needs Pillow): python3 tools/art/make_art.py

The borjgali here uses the same curves as DesignSystem/Components/Borjgali.swift.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Georgian", "Assets.xcassets")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def quad(p0, p1, p2, n=48):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


def borjgali(draw, cx, cy, r, fill, rot=0.0):
    def pt(rad, ang):
        return (cx + math.cos(ang) * rad * r, cy + math.sin(ang) * rad * r)
    for i in range(7):
        a = i / 7 * 2 * math.pi + rot
        poly = quad(pt(0.14, a), pt(1.0, a + 0.25), pt(0.92, a + 1.25)) + quad(pt(0.92, a + 1.25), pt(0.62, a + 1.0), pt(0.14, a + 0.62))
        draw.polygon(poly, fill=fill)
    draw.ellipse((cx - r * 0.18, cy - r * 0.18, cx + r * 0.18, cy + r * 0.18), fill=fill)


def icon():
    S = 1024
    bg = Image.new("RGB", (S, S))
    c1, c2 = (226, 59, 78), (122, 59, 194)
    px = bg.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)
            px[x, y] = tuple(int(c1[k] * (1 - t) + c2[k] * t) for k in range(3))
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse((520, -200, 1300, 560), fill=110)
    bg = Image.composite(Image.new("RGB", (S, S), (255, 220, 170)), bg, glow.filter(ImageFilter.GaussianBlur(120)))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    borjgali(ImageDraw.Draw(layer), S / 2, S / 2, 470, (255, 194, 92, 105), rot=0.2)
    out = Image.alpha_composite(bg.convert("RGBA"), layer)
    f = ImageFont.truetype(FONT, 560)
    d = ImageDraw.Draw(out)
    b = d.textbbox((0, 0), "ა", font=f)
    w, h = b[2] - b[0], b[3] - b[1]
    pos = ((S - w) / 2 - b[0], (S - h) / 2 - b[1])
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((pos[0], pos[1] + 24), "ა", font=f, fill=(60, 10, 40, 120))
    out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(18)))
    ImageDraw.Draw(out).text(pos, "ა", font=f, fill=(255, 255, 255, 255))
    out.convert("RGB").save(os.path.join(ROOT, "AppIcon.appiconset", "icon-1024.png"))


def launch():
    for scale in (1, 2, 3):
        s = 120 * scale
        im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        borjgali(ImageDraw.Draw(im), s / 2, s / 2, s / 2 * 0.96, (226, 59, 78, 255))
        im.save(os.path.join(ROOT, "LaunchMark.imageset", f"launch@{scale}x.png"))


icon()
launch()
print("icon and launch mark written")
