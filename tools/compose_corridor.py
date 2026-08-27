#!/usr/bin/env python3
"""Composes the follow-mode terrain strip for the BZN -> BIL corridor.

    python3 tools/compose_corridor.py

Reads the 48px crops that tools/curate.py (tools/curation/terrain.py) extracts
to assets/art/production/world/terrain/ and writes one 2560x360 strip to
assets/art/production/world/corridor_bzn_bil.png.

The strip is a west-to-east journey painted at fixed positions with a seeded
RNG for the scatter, so a re-run reproduces the same world: grassy plains with
scattered trees, a fenced farm, a river crossing, a dense forest, a small town
on a cobbled road, brown foothills and finally snow-capped mountains, easing
back to plains at the far end so the two ends of the journey blend.

This is offline composition: the game only ever loads the finished strip.
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILES = ROOT / "assets" / "art" / "production" / "world" / "terrain"
OUT = ROOT / "assets" / "art" / "production" / "world" / "corridor_bzn_bil.png"

WIDTH, HEIGHT = 2560, 360
SEED = 0x42_5A4E  # "BZN"

_cache: dict[str, Image.Image] = {}


def tile(name: str) -> Image.Image:
    if name not in _cache:
        _cache[name] = Image.open(TILES / f"{name}.png").convert("RGBA")
    return _cache[name]


def mirrored(name: str) -> Image.Image:
    key = f"{name}|mirror"
    if key not in _cache:
        _cache[key] = tile(name).transpose(Image.FLIP_LEFT_RIGHT)
    return _cache[key]


def paste_opaque(canvas: Image.Image, im: Image.Image, x: int, y: int) -> None:
    canvas.paste(im, (x, y))


def blit(canvas: Image.Image, im: Image.Image, x: int, y: int) -> None:
    canvas.alpha_composite(im, (max(0, x), max(0, y)))


# ---------------------------------------------------------------------------
# Ground
# ---------------------------------------------------------------------------

def lay_grass(canvas: Image.Image, rng: random.Random) -> None:
    # One base tile everywhere with sparse variants: mixing every variant per
    # cell reads as a patchwork quilt from the air.
    variants = ["grass_d", "grass_e"]
    for ty in range(0, HEIGHT, 48):
        for tx in range(0, WIDTH, 48):
            name = rng.choice(variants) if rng.random() < 0.08 else "grass_b"
            canvas.paste(tile(name), (tx, ty))


def lay_river(canvas: Image.Image, x: int) -> None:
    """A vertical river: west bank, water, east bank columns."""
    for ty in range(0, HEIGHT, 48):
        row = ty // 48
        canvas.paste(tile("bank_west_a" if row % 2 else "bank_west_b"), (x, ty))
        canvas.paste(tile("water_a" if row % 2 else "water_b"), (x + 48, ty))
        canvas.paste(tile("bank_east_a" if row % 2 else "bank_east_b"), (x + 96, ty))


def lay_road(canvas: Image.Image, x: int) -> None:
    """A vertical cobbled lane with its grassy centre line."""
    for ty in range(0, HEIGHT, 48):
        row = ty // 48
        canvas.paste(tile("road_edge_w_a" if row % 2 else "road_edge_w_b"), (x, ty))
        canvas.paste(tile("road_mid_a" if row % 3 else "road_mid_a2"), (x + 48, ty))
        canvas.paste(mirrored("road_edge_w_b" if row % 2 else "road_edge_w_a"), (x + 96, ty))


# ---------------------------------------------------------------------------
# Scatter helpers
# ---------------------------------------------------------------------------

def scatter(canvas: Image.Image, rng: random.Random, props: list,
            x0: int, x1: int, count: int, y0: int = 24, y1: int = 300,
            keep_out: list | None = None, overlap: int = 8) -> list:
    """Scatters props into [x0,x1), avoiding keep_out rects. Props may overlap
    each other by up to `overlap` pixels (dense woods want big overlaps).
    Returns placed (x, y, im) tuples so callers can depth-sort before drawing."""
    placed = []
    tries = 0
    while len(placed) < count and tries < count * 40:
        tries += 1
        name = rng.choice(props)
        im = tile(name)
        x = rng.randrange(x0, max(x0 + 1, x1 - im.width))
        y = rng.randrange(y0, max(y0 + 1, y1 - im.height))
        rect = (x, y, x + im.width, y + im.height)
        if any(_overlaps(rect, k) for k in (keep_out or [])):
            continue
        if any(_overlaps(rect, (px, py, px + p.width, py + p.height), pad=-overlap)
               for px, py, p in placed):
            continue
        placed.append((x, y, im))
    return placed


def _overlaps(a: tuple, b: tuple, pad: int = 0) -> bool:
    return not (a[2] + pad <= b[0] or b[2] + pad <= a[0]
                or a[3] + pad <= b[1] or b[3] + pad <= a[1])


def draw_sorted(canvas: Image.Image, placed: list) -> None:
    for x, y, im in sorted(placed, key=lambda p: p[1] + p[2].height):
        blit(canvas, im, x, y)


# ---------------------------------------------------------------------------
# The journey
# ---------------------------------------------------------------------------

def compose() -> Image.Image:
    rng = random.Random(SEED)
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 255))
    lay_grass(canvas, rng)

    keep_out: list[tuple] = []
    deferred: list = []  # props drawn painter-sorted at the end

    # -- River crossing (ground first, so bank bushes can sit on it) --------
    lay_river(canvas, 920)
    keep_out.append((900, 0, 1084, HEIGHT))

    # -- Farm ---------------------------------------------------------------
    plots = [("plot_b", 440, 96), ("plot_c", 540, 96),
             ("plot_a", 440, 196), ("plot_d", 540, 196)]
    for name, px, py in plots:
        blit(canvas, tile(name), px, py)
    fence = tile("fence")
    for fx in (438, 534):
        blit(canvas, fence, fx, 66)
        blit(canvas, fence, fx, 292)
    deferred.append((648, 128, tile("house_b")))
    keep_out.append((420, 40, 700, 320))

    # -- Forest -------------------------------------------------------------
    # Two passes: a dense overlapping canopy of big trees, then pines and
    # brush filling the gaps and softening the fringe.
    forest_core = ["tree_big_a", "tree_big_b", "tree_big_a", "tree_big_b"]
    deferred += scatter(canvas, rng, forest_core, 1120, 1440, 30, 0, 340, overlap=28)
    deferred += scatter(canvas, rng, ["pine_a", "pine_b", "tree_small"],
                        1100, 1460, 16, 0, 330, overlap=20)
    deferred += scatter(canvas, rng, ["bush_b", "bush_c", "pine_small_a", "pine_small_b"],
                        1080, 1470, 10, 20, 320, overlap=12)
    keep_out.append((1080, 0, 1470, HEIGHT))

    # -- Town ---------------------------------------------------------------
    lay_road(canvas, 1540)
    deferred.append((1440, 44, tile("church")))  # overlooks the lane
    houses_west = [("house_a", 1468, 158), ("house_e", 1454, 254)]
    houses_east = [("house_d", 1692, 64), ("house_f", 1698, 156), ("house_c", 1694, 252)]
    for name, hx, hy in houses_west + houses_east:
        deferred.append((hx, hy, tile(name)))
    keep_out.append((1436, 0, 1746, HEIGHT))

    # -- Foothills and mountains -------------------------------------------
    # The foothills are a subalpine belt: dense pines, boulders and rocks
    # climbing toward the snow massif.
    blit(canvas, tile("mountains_big"), 1996, 54)
    keep_out.append((2016, 50, 2480, 310))
    deferred += scatter(canvas, rng, ["pine_a", "pine_b", "pine_a", "pine_b",
                                      "pine_small_a", "pine_small_b", "rock_a",
                                      "rock_b", "bush_c"],
                        1756, 2020, 22, 6, 336, keep_out=keep_out, overlap=18)
    # Straddle the massif crop's rectangle so its grass background never reads
    # as an edge against the base grass.
    for name, px, py in [("tuft_a", 2040, 40), ("rock_b", 2200, 34),
                         ("bush_c", 2380, 40), ("pine_b", 1968, 120),
                         ("bush_b", 1980, 226), ("bush_d", 2090, 292),
                         ("tuft_b", 2300, 296)]:
        deferred.append((px, py, tile(name)))

    # -- Scattered life on the plains ---------------------------------------
    plains_props = ["tree_big_a", "tree_big_b", "tree_small", "pine_a",
                    "bush_a", "bush_b", "bush_c", "bush_d",
                    "tuft_a", "tuft_b", "rock_a"]
    deferred += scatter(canvas, rng, plains_props, 20, 420, 14, keep_out=keep_out)
    deferred += scatter(canvas, rng, ["bush_a", "tuft_a", "tuft_b",
                                      "pine_small_a"], 370, 720, 6, keep_out=keep_out)
    deferred += scatter(canvas, rng, plains_props, 690, 918, 8, keep_out=keep_out)
    # Bushes and rocks along the river banks.
    deferred += scatter(canvas, rng, ["bush_b", "bush_c", "tuft_a", "rock_b"],
                        878, 926, 4, 20, 320)
    deferred += scatter(canvas, rng, ["bush_a", "bush_d", "tuft_b", "rock_a"],
                        1058, 1106, 4, 20, 320)
    # The far end eases back to plains: pines, rocks, then open grass.
    deferred += scatter(canvas, rng, ["pine_a", "pine_small_a", "pine_small_b",
                                      "rock_b", "bush_c", "tuft_a"],
                        2440, 2556, 5, keep_out=keep_out)

    draw_sorted(canvas, deferred)
    return canvas


def main() -> None:
    strip = compose()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    strip.save(OUT)
    stale = OUT.with_suffix(".png.import")
    if stale.exists():
        stale.unlink()
    print(f"wrote {OUT.relative_to(ROOT)} ({strip.width}x{strip.height})")


if __name__ == "__main__":
    main()
