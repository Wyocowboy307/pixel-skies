#!/usr/bin/env python3
"""Composes the original Trailhopper hero from the flight construction kit.

The library rule: flight/1 is the construction vocabulary; the hero itself is an
original Pixel Skies aircraft. Parts are cropped generously, alpha-trimmed, and
assembled; the orange livery trim and the propeller are the deliberate custom
additions that make it ours.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets/library/PixelSkies_Curated_Assets/02_AIRCRAFT_AND_CABIN/flight/1.png"
OUT = ROOT / ".art_candidates"


def trim(image: Image.Image) -> Image.Image:
    data = np.array(image)
    alpha = data[:, :, 3]
    ys, xs = np.where(alpha > 8)
    if not ys.size:
        return image
    return image.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def part(x: int, y: int, w: int, h: int) -> Image.Image:
    return trim(Image.open(SHEET).convert("RGBA").crop((x, y, x + w, y + h)))


ORANGE = (224, 139, 60, 255)
ORANGE_DEEP = (192, 90, 74, 255)
ORANGE_HI = (242, 177, 103, 255)
OUTLINE = (56, 44, 40, 255)


def paint_band(image: Image.Image, y0f: float, y1f: float,
               colours=(ORANGE, ORANGE_DEEP)) -> None:
    """Recolours the body pixels in a horizontal band to the orange livery,
    keeping the sheet's own light/dark shading split."""
    data = np.array(image)
    h = data.shape[0]
    y0, y1 = int(h * y0f), int(h * y1f)
    band = data[y0:y1]
    rgbs = band[:, :, :3].astype(int)
    alpha = band[:, :, 3]
    brightness = rgbs.sum(axis=2)
    # Only recolour the warm hull tones; leave glass, outlines and metal alone.
    warm = (rgbs[:, :, 0] >= rgbs[:, :, 2] - 8) & (alpha > 100) & (brightness > 260)
    light = warm & (brightness >= 560)
    dark = warm & ~light
    band[light] = colours[0]
    band[dark] = colours[1]
    data[y0:y1] = band
    image.paste(Image.fromarray(data), (0, 0))


def compose_side() -> Image.Image:
    # Parts from flight/1 (generous crops, trimmed).
    nose = part(536, 96, 96, 48)          # rounded nose + cockpit glazing
    cabin = part(288, 144, 48, 48)        # one window segment
    cabin2 = part(432, 144, 48, 48)       # second segment, more windows
    tail = part(240, 96, 72, 48)          # rear taper from the light airliner
    fin = part(528, 96, 56, 96)           # tall fin
    wing = part(192, 336, 150, 44)        # side wing blade
    wheel = part(672, 192, 48, 48)        # fat tire
    small_wheel = part(672, 240, 44, 48)

    body_h = max(nose.height, cabin.height, tail.height)
    canvas = Image.new("RGBA", (240, 140), (0, 0, 0, 0))
    baseline = 120

    # Assemble right-to-left: nose at the right, then cabin, then tail.
    x = 210
    body_top = baseline - 34 - wheel.height // 2
    x -= nose.width; canvas.alpha_composite(nose, (x, body_top))
    x -= cabin2.width - 2; canvas.alpha_composite(cabin2, (x, body_top))
    x -= cabin.width - 2; canvas.alpha_composite(cabin, (x, body_top))
    x -= tail.width - 4; canvas.alpha_composite(tail, (x, body_top))

    # Fin over the tail, wing over the cabin.
    canvas.alpha_composite(fin, (x - 2, body_top - fin.height + 26))
    canvas.alpha_composite(wing, (x + tail.width - 10, body_top + 18))

    # Gear.
    canvas.alpha_composite(wheel, (128, baseline - wheel.height + 6))
    canvas.alpha_composite(small_wheel, (176, baseline - small_wheel.height + 4))
    return trim(canvas)


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    side = compose_side()
    side.save(OUT / "hero_flightkit_raw.png")
    print("raw composite:", side.size)
