#!/usr/bin/env python3
"""Composes the follow-mode terrain strip for the BZN -> BIL corridor.

    python3 tools/compose_corridor.py

Reads the 48px crops that tools/curate.py (tools/curation/terrain.py) extracts
to assets/art/production/world/terrain/ and writes one 2560x360 strip to
assets/art/production/world/corridor_bzn_bil.png.

The strip is a west-to-east journey painted at fixed positions with a seeded
RNG for the scatter, so a re-run reproduces the same world.  Sampled by
enroute progress (BZN west -> BIL east) the journey reads: BZN foothills and
pines under a small snow massif, open plains with a fenced farm, a river
crossing with cattails and lily pads, a dense mixed forest, a small town on a
cobbled road, pine foothills seating the big snow-capped massif, and finally
open BIL plains.

Tree language: tree_big_a/b, tree_small and pine_a/b are the trees (mixed
woodland is deliberate); bush_a-d and tufts are undergrowth that only appears
tucked around trees, along banks and fences, never alone in open grass.

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


def keyed(name: str) -> Image.Image:
    """The cattail/lily crops sit on overworld/7's flat river blue, which is
    lighter than the corridor's lake water; key the water out so only the
    plants composite onto the river."""
    key = f"{name}|keyed"
    if key not in _cache:
        im = tile(name).copy()
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a > 0 and b > g and b > r + 30 and b > 120:
                    px[x, y] = (0, 0, 0, 0)
        _cache[key] = im
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


TREES = ["tree_big_a", "tree_big_b", "tree_small"]
PINES = ["pine_a", "pine_b"]
UNDERGROWTH = ["bush_a", "bush_b", "bush_c", "bush_d", "tuft_a", "tuft_b"]


def copse(canvas: Image.Image, rng: random.Random, cx: int, cy: int,
          trees: list | None = None, n_trees: int = 3, n_under: int = 3,
          under: list | None = None, keep_out: list | None = None) -> list:
    """A tight cluster of trees with undergrowth tucked at their feet: the
    way trees actually stand on plains.  The undergrowth band sits lower than
    the tree band so painter sorting keeps bushes in front of trunks."""
    trees = trees or TREES
    under = under or UNDERGROWTH
    ty0 = max(0, cy - 56)
    ty1 = min(340, cy + 56)
    placed = scatter(canvas, rng, trees, cx - 80, cx + 80, n_trees,
                     ty0, ty1, keep_out=keep_out, overlap=26)
    placed += scatter(canvas, rng, under, cx - 92, cx + 92, n_under,
                      min(ty1 - 4, cy - 8), min(348, cy + 88),
                      keep_out=keep_out, overlap=14)
    return placed


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
    # Cattails at the water's edge and lily pads drifting on the current
    # (water column spans x 968..1016).
    blit(canvas, keyed("cattails_a"), 966, 64)
    blit(canvas, keyed("cattails_a").transpose(Image.FLIP_LEFT_RIGHT), 972, 258)
    blit(canvas, keyed("lily_a"), 968, 140)
    blit(canvas, keyed("lily_b"), 968, 306)
    blit(canvas, keyed("lily_b").transpose(Image.FLIP_LEFT_RIGHT), 968, 14)

    # -- BZN foothills: the west end opens under a small snow massif --------
    blit(canvas, tile("mountains_small"), 16, 48)
    # Straddle the massif crop's grass rectangle so it never reads as an edge.
    for entry in [(8, 232, tile("pine_a")), (222, 218, tile("pine_b")),
                  (60, 36, tile("tuft_a")), (196, 288, tile("boulder_c")),
                  (150, 30, tile("tuft_b"))]:
        deferred.append(entry)
    keep_out.append((30, 64, 242, 276))
    # A foothill mound seats the massif's south-east flank.
    deferred.append((216, 232, tile("foothill_big")))
    keep_out.append((236, 268, 390, 324))
    # Pine copses climbing off the foothills, with boulder accents.
    deferred += copse(canvas, rng, 316, 96, trees=PINES + ["pine_a"],
                      n_trees=3, n_under=2, keep_out=keep_out)
    # Below the massif only 48px growth fits above the strip edge, so the
    # south-west cluster is small pines with brush at their feet.
    for entry in [(70, 296, tile("pine_small_a")), (118, 304, tile("pine_small_b")),
                  (52, 320, tile("bush_c")), (152, 322, tile("tuft_a"))]:
        deferred.append(entry)
    deferred += scatter(canvas, rng, ["pine_small_a", "pine_small_b",
                                      "boulder_a", "rock_a"],
                        8, 400, 5, 6, 336, keep_out=keep_out, overlap=12)

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
    # A farmhouse garden and hedge-line accents along the fences.
    deferred.append((642, 176, tile("flower_bush_pink")))
    deferred.append((602, 66, tile("flowers_a")))
    deferred.append((444, 300, tile("tuft_a")))
    deferred.append((560, 296, tile("tuft_b")))
    deferred.append((654, 262, tile("stump_a")))
    keep_out.append((420, 40, 700, 320))

    # -- Plains between the farm and the river ------------------------------
    # Trees stand in copses with their own undergrowth; the open grass keeps
    # only flowers and the odd boulder, never a lone bush.
    deferred += copse(canvas, rng, 770, 110, n_trees=3, n_under=3,
                      keep_out=keep_out)
    deferred += copse(canvas, rng, 838, 268, n_trees=2, n_under=3,
                      keep_out=keep_out)
    deferred.append((716, 210, tile("tree_big_a")))
    deferred.append((792, 296, tile("bush_b")))  # at the lone tree's foot
    deferred += scatter(canvas, rng, ["flowers_a", "flowers_b", "boulder_a"],
                        700, 918, 4, keep_out=keep_out, overlap=0)
    deferred += scatter(canvas, rng, ["flowers_a", "flowers_b"],
                        360, 716, 3, keep_out=keep_out, overlap=0)
    # Bushes, rocks and pebbles along the river banks.  (The bands are wider
    # than a prop so placements stagger instead of column-aligning.)
    deferred += scatter(canvas, rng, ["bush_b", "bush_c", "tuft_a", "pebbles_a"],
                        852, 932, 5, 16, 330)
    deferred += scatter(canvas, rng, ["bush_a", "bush_d", "tuft_b", "pebbles_a"],
                        1052, 1122, 5, 16, 330)

    # -- Forest -------------------------------------------------------------
    # Two passes: a dense overlapping canopy of big trees, then pines and
    # brush filling the gaps and softening the fringe.
    forest_core = ["tree_big_a", "tree_big_b", "tree_big_a", "tree_big_b"]
    deferred += scatter(canvas, rng, forest_core, 1120, 1440, 30, 0, 340, overlap=28)
    deferred += scatter(canvas, rng, ["pine_a", "pine_b", "tree_small"],
                        1100, 1460, 16, 0, 330, overlap=20)
    deferred += scatter(canvas, rng, ["bush_b", "bush_c", "pine_small_a", "pine_small_b"],
                        1080, 1470, 10, 20, 320, overlap=12)
    # A clearing edge: stump and forest flowers on the west fringe.
    deferred.append((1094, 302, tile("stump_a")))
    deferred.append((1088, 44, tile("flowers_b")))
    keep_out.append((1080, 0, 1470, HEIGHT))

    # -- Town ---------------------------------------------------------------
    lay_road(canvas, 1540)
    deferred.append((1440, 44, tile("church")))  # overlooks the lane
    houses_west = [("house_a", 1468, 158), ("house_e", 1454, 254)]
    houses_east = [("house_d", 1692, 64), ("house_f", 1698, 156), ("house_c", 1694, 252)]
    for name, hx, hy in houses_west + houses_east:
        deferred.append((hx, hy, tile(name)))
    # Front gardens: flowering bushes and flower beds between the houses.
    deferred.append((1506, 210, tile("flower_bush_pink")))
    deferred.append((1444, 146, tile("flower_bush_yellow")))
    deferred.append((1452, 306, tile("flowers_a")))
    deferred.append((1698, 308, tile("flowers_b")))
    deferred.append((1700, 104, tile("flower_bush_pink")))
    keep_out.append((1436, 0, 1746, HEIGHT))

    # -- Foothills and mountains -------------------------------------------
    # The foothills are a subalpine belt: pine copses, foothill mounds and
    # boulders climbing toward the snow massif.
    blit(canvas, tile("mountains_big"), 1996, 54)
    keep_out.append((2016, 50, 2480, 310))
    # Foothill mounds seat the massif's flanks.
    deferred.append((1880, 226, tile("foothill_big")))
    deferred.append((2270, 240, mirrored("foothill_big")))
    deferred += copse(canvas, rng, 1800, 110, trees=PINES + ["pine_a"],
                      n_trees=3, n_under=2, keep_out=keep_out)
    deferred += copse(canvas, rng, 1930, 160, trees=PINES,
                      n_trees=2, n_under=2, keep_out=keep_out)
    deferred += copse(canvas, rng, 1808, 288, trees=PINES,
                      n_trees=2, n_under=1, keep_out=keep_out)
    deferred += scatter(canvas, rng, ["pine_small_a", "pine_small_b",
                                      "boulder_a", "boulder_b", "rock_a", "rock_b"],
                        1756, 2020, 8, 6, 336, keep_out=keep_out, overlap=12)
    # Straddle the massif crop's rectangle so its grass background never reads
    # as an edge against the base grass.
    for name, px, py in [("tuft_a", 2040, 40), ("rock_b", 2200, 34),
                         ("bush_c", 2380, 40), ("pine_b", 1968, 120),
                         ("bush_b", 1980, 226), ("boulder_a", 2088, 290),
                         ("tuft_b", 2300, 296)]:
        deferred.append((px, py, tile(name)))

    # -- BIL plains: the journey eases out into open grass ------------------
    deferred.append((2496, 156, tile("tree_small")))
    deferred.append((2510, 246, tile("tuft_a")))  # at the tree's foot
    deferred.append((2500, 60, tile("flowers_b")))
    deferred.append((2526, 302, tile("flowers_a")))

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
