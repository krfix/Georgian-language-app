#!/usr/bin/env python3
"""Draws the app icon (the Ara parrot), the mascot and the launch mark (needs Pillow):

    python3 tools/art/make_art.py

The parrot is in parrot.py; the borjgali here uses the same curves as
DesignSystem/Components/Borjgali.swift.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parrot import parrot  # noqa: E402
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
    parrot(bg=True).convert("RGB").save(os.path.join(ROOT, "AppIcon.appiconset", "icon-1024.png"))


def mascot():
    """The parrot on a clear background, cropped to it, for the app's screens."""
    im = parrot(bg=False)
    im = im.crop(im.getbbox())
    folder = os.path.join(ROOT, "Parrot.imageset")
    os.makedirs(folder, exist_ok=True)
    for scale in (1, 2, 3):
        w = 160 * scale
        im.resize((w, int(im.height * w / im.width)), resample=1).save(os.path.join(folder, f"parrot@{scale}x.png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write('{ "images" : [\n'
                '  { "filename" : "parrot@1x.png", "idiom" : "universal", "scale" : "1x" },\n'
                '  { "filename" : "parrot@2x.png", "idiom" : "universal", "scale" : "2x" },\n'
                '  { "filename" : "parrot@3x.png", "idiom" : "universal", "scale" : "3x" }\n'
                ' ], "info" : { "author" : "xcode", "version" : 1 } }\n')


def launch():
    im = parrot(bg=False)
    im = im.crop(im.getbbox())
    for scale in (1, 2, 3):
        w = 110 * scale
        im.resize((w, int(im.height * w / im.width)), resample=1).save(os.path.join(ROOT, "LaunchMark.imageset", f"launch@{scale}x.png"))


icon()
mascot()
launch()
print("icon, mascot and launch mark written")
