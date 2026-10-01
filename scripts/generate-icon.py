#!/usr/bin/env python3
"""Draws Config/AppIcon.png: a decade of gold beads and a cross on a night-blue field.

Requires Pillow (`pip install --target /tmp/pylib pillow`, then run with PYTHONPATH=/tmp/pylib).
The output is a 1024x1024 opaque PNG, which is what xtool expects for iconPath.
"""

import math
import pathlib
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4
S = SIZE * SCALE

NIGHT_CENTER = (30, 46, 82)
NIGHT_EDGE = (8, 14, 30)
GOLD = (222, 184, 102)
GOLD_DARK = (146, 108, 46)
GOLD_LIGHT = (252, 236, 190)

RING_CENTER = (512, 380)
RING_RADIUS = 240
BEAD_RADIUS = 30
MEDAL_RADIUS = 38
CORD_WIDTH = 9


def px(value):
    return round(value * SCALE)


def solid(color):
    return Image.new("RGB", (S, S), color)


def ellipse(draw, cx, cy, r, **kwargs):
    draw.ellipse((px(cx - r), px(cy - r), px(cx + r), px(cy + r)), **kwargs)


def layout():
    cx, cy = RING_CENTER
    beads = []
    for i in range(1, 11):
        angle = math.pi / 2 + i * 2 * math.pi / 11
        beads.append((cx + RING_RADIUS * math.cos(angle), cy + RING_RADIUS * math.sin(angle), BEAD_RADIUS))
    beads.append((cx, 680, 22))
    medal = (cx, cy + RING_RADIUS, MEDAL_RADIUS)
    return beads, medal


def flat_parts():
    """The cord, the chain to the cross, and the cross: gold without bead shading."""
    mask = Image.new("L", (S, S), 0)
    draw = ImageDraw.Draw(mask)
    cx, cy = RING_CENTER
    ellipse(draw, cx, cy, RING_RADIUS + CORD_WIDTH / 2, outline=255, width=px(CORD_WIDTH))
    draw.line((px(cx), px(cy + RING_RADIUS), px(cx), px(730)), fill=255, width=px(CORD_WIDTH))
    bar = 30
    draw.rectangle((px(cx - bar / 2), px(722), px(cx + bar / 2), px(902)), fill=255)
    draw.rectangle((px(cx - 62), px(768), px(cx + 62), px(768 + bar)), fill=255)
    return mask


def round_parts(beads, medal):
    mask = Image.new("L", (S, S), 0)
    draw = ImageDraw.Draw(mask)
    for x, y, r in [*beads, medal]:
        ellipse(draw, x, y, r, fill=255)
    return mask


def offset_circles(circles, shift, scale, blur):
    mask = Image.new("L", (S, S), 0)
    draw = ImageDraw.Draw(mask)
    for x, y, r in circles:
        ellipse(draw, x - r * shift, y - r * shift, r * scale, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(px(blur)))


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "Config/AppIcon.png")
    beads, medal = layout()
    circles = [*beads, medal]

    image = Image.composite(solid(NIGHT_EDGE), solid(NIGHT_CENTER), Image.radial_gradient("L").resize((S, S)))

    flat = flat_parts()
    shape = ImageChops.lighter(flat, round_parts(beads, medal))

    halo = shape.filter(ImageFilter.GaussianBlur(px(18))).point(lambda v: int(v * 0.35))
    image = Image.composite(solid(GOLD), image, halo)

    lit = ImageChops.lighter(offset_circles(circles, shift=0.18, scale=0.9, blur=6), flat)
    image = Image.composite(Image.composite(solid(GOLD), solid(GOLD_DARK), lit), image, shape)

    medal_ring = Image.new("L", (S, S), 0)
    ellipse(ImageDraw.Draw(medal_ring), medal[0], medal[1], 23, outline=255, width=px(4))
    image = Image.composite(solid(GOLD_DARK), image, medal_ring)

    highlight = offset_circles(circles, shift=0.38, scale=0.28, blur=4).point(lambda v: int(v * 0.85))
    image = Image.composite(solid(GOLD_LIGHT), image, highlight)

    image.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(out, optimize=True)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
