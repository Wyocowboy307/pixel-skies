#!/usr/bin/env python3
"""Offline world-map preprocessing for Pixel Skies.

Turns public-domain Natural Earth vector data into stylized pixel-art LOD
textures. This runs offline by design: the game ships PNGs and never parses
GeoJSON or links a GIS library at runtime (see docs/WORLD_MAP_AND_ZOOM.md).

    python3 tools/build_world_geometry.py

Source data is cached in tools/.ne_cache/ (gitignored). Outputs:
    assets/art/world/world_lod0.png   1024x512   whole-world view
    assets/art/world/world_lod1.png   2048x1024  continental view
    assets/art/world/world_lod2.png   4096x2048  regional view
    data/world/world_meta.json        palette + projection metadata

Natural Earth is public domain: https://www.naturalearthdata.com/about/terms-of-use/
"""

from __future__ import annotations

import json
import math
import os
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelart.palette import ALLOWED_RGB, rgb  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".ne_cache"
ART_OUT = ROOT / "assets" / "art" / "world"
DATA_OUT = ROOT / "data" / "world"

BASE_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"

# ---------------------------------------------------------------------------
# The map draws from the same locked palette as every sprite, so the world can
# never drift into a different colour language from the aircraft standing on it
# (docs/PIXEL_STYLE_GUIDE.md section 2).
#
# Nothing here blends or multiplies colours: a blend of two palette entries is
# not a palette entry. Shading is done with ordered dithering between two
# palette colours instead, which is also what makes the map read as pixel art
# rather than as a smooth vector fill.
# ---------------------------------------------------------------------------
OCEAN_DEEP = "water_deep"
OCEAN = "water"
SHELF = "water_shelf"
COAST = "outline"
COAST_LIT = "tundra"
LAKE = "water_shelf"
BORDER = "outline"

# Latitude colour bands, coldest first. Stylized rather than climatological.
LAT_BANDS = [
    (72.0, "ice"),
    (60.0, "tundra"),
    (50.0, "grass_dark"),
    (34.0, "grass"),
    (20.0, "sand"),
    (10.0, "scrub"),
    (0.0, "grass_dark"),
]

# Darker partner used to dither the interior of each band, giving landmasses
# depth without inventing a colour.
BAND_SHADE = {
    "ice": "ice",
    "tundra": "grass_dark",
    "grass_dark": "outline",
    "grass": "grass_dark",
    "sand": "soil",
    "scrub": "grass_dark",
}

# How far a band boundary may wander, in degrees of latitude.
BAND_NOISE_DEGREES = 9.0
BAND_DITHER_DEGREES = 2.5

BAYER4 = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
], dtype=np.float32) / 16.0


class Lod:
    def __init__(self, name, width, height, land_src, simplify_px,
                 min_area_px, shelf_px, lakes, borders, states, dither_scale=1.0):
        self.name = name
        self.width = width
        self.height = height
        self.land_src = land_src
        self.simplify_px = simplify_px
        self.min_area_px = min_area_px
        self.shelf_px = shelf_px
        self.lakes = lakes
        self.borders = borders
        self.states = states
        # Finer tiers are viewed closer, where a heavy stipple stops reading as
        # terrain and starts reading as screen noise.
        self.dither_scale = dither_scale


# Three tiers, sized so each one displays at an integer scale at a camera zoom
# stop (see docs/WORLD_MAP_AND_ZOOM.md). World space is 4096x2048 units, so lod0
# draws at 4x, lod1 at 2x and lod2 at 1x — no fractional texel sampling, which
# is what keeps pixel art from shimmering while zooming.
LODS = [
    Lod("lod0", 512, 256, "ne_110m_land", 1.1, 4.0, 1,
        lakes=None, borders=None, states=None),
    Lod("lod1", 1024, 512, "ne_110m_land", 0.9, 5.0, 2,
        lakes="ne_50m_lakes", borders=None, states=None),
    Lod("lod2", 2048, 1024, "ne_110m_land", 0.75, 6.0, 3,
        lakes="ne_50m_lakes", borders="ne_110m_admin_0_boundary_lines_land", states=None,
        dither_scale=0.7),
    Lod("lod3", 4096, 2048, "ne_50m_land", 0.6, 8.0, 4,
        lakes="ne_50m_lakes", borders="ne_50m_admin_0_boundary_lines_land",
        states="ne_50m_admin_1_states_provinces_lines", dither_scale=0.45),
]


def fetch(name: str) -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{name}.geojson"
    if not path.exists():
        url = f"{BASE_URL}/{name}.geojson"
        print(f"  downloading {name} ...")
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                path.write_bytes(response.read())
        except Exception as exc:  # noqa: BLE001 - offline is a normal failure here
            sys.exit(f"Could not download {url}: {exc}\n"
                     f"Place the file at {path} manually and re-run.")
    return json.loads(path.read_text())


def project(lon: float, lat: float, w: int, h: int) -> tuple[float, float]:
    """Equirectangular, matching WorldProjection.lat_lon_to_map exactly."""
    return ((lon + 180.0) / 360.0) * w, ((90.0 - lat) / 180.0) * h


def rings_of(geometry: dict):
    kind = geometry.get("type")
    coords = geometry.get("coordinates") or []
    if kind == "Polygon":
        yield coords
    elif kind == "MultiPolygon":
        for polygon in coords:
            yield polygon


def lines_of(geometry: dict):
    kind = geometry.get("type")
    coords = geometry.get("coordinates") or []
    if kind == "LineString":
        yield coords
    elif kind == "MultiLineString":
        for line in coords:
            yield line


def simplify(points: list[tuple[float, float]], tolerance: float) -> list[tuple[float, float]]:
    """Iterative Douglas-Peucker. Keeps the deliberate, stylized silhouette and
    strips sub-pixel noise that would otherwise dither the coastline."""
    if len(points) < 3 or tolerance <= 0.0:
        return points
    keep = np.zeros(len(points), dtype=bool)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        start, end = stack.pop()
        if end <= start + 1:
            continue
        ax, ay = points[start]
        bx, by = points[end]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy)
        best_index, best_distance = -1, 0.0
        for i in range(start + 1, end):
            px, py = points[i]
            if length < 1e-12:
                distance = math.hypot(px - ax, py - ay)
            else:
                distance = abs(dy * px - dx * py + bx * ay - by * ax) / length
            if distance > best_distance:
                best_index, best_distance = i, distance
        if best_index >= 0 and best_distance > tolerance:
            keep[best_index] = True
            stack.append((start, best_index))
            stack.append((best_index, end))
    return [p for p, k in zip(points, keep) if k]


def ring_area(points: list[tuple[float, float]]) -> float:
    total = 0.0
    for i in range(len(points)):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % len(points)]
        total += x1 * y2 - x2 * y1
    return abs(total) * 0.5


def polygon_mask(features, lod: Lod) -> np.ndarray:
    """Rasterize GeoJSON polygons into a boolean mask at LOD resolution.

    Interior rings are punched out so lakes-in-islands and inland seas read
    correctly rather than filling solid.
    """
    mask = Image.new("1", (lod.width, lod.height), 0)
    draw = ImageDraw.Draw(mask)
    outers, holes = [], []
    for feature in features:
        geometry = feature.get("geometry") or {}
        for polygon in rings_of(geometry):
            for index, ring in enumerate(polygon):
                points = [project(x, y, lod.width, lod.height) for x, y in ring]
                points = simplify(points, lod.simplify_px)
                if len(points) < 3 or ring_area(points) < lod.min_area_px:
                    continue
                (holes if index else outers).append(points)
    for points in outers:
        draw.polygon(points, fill=1)
    for points in holes:
        draw.polygon(points, fill=0)
    return np.array(mask, dtype=bool)


def line_mask(features, lod: Lod, tolerance: float) -> np.ndarray:
    mask = Image.new("1", (lod.width, lod.height), 0)
    draw = ImageDraw.Draw(mask)
    for feature in features:
        geometry = feature.get("geometry") or {}
        for line in lines_of(geometry):
            points = [project(x, y, lod.width, lod.height) for x, y in line]
            points = simplify(points, tolerance)
            if len(points) >= 2:
                draw.line(points, fill=1, width=1)
    return np.array(mask, dtype=bool)


def shift(mask: np.ndarray, dy: int, dx: int) -> np.ndarray:
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(0, dy), h + min(0, dy))
    xs = slice(max(0, dx), w + min(0, dx))
    yt = slice(max(0, -dy), h + min(0, -dy))
    xt = slice(max(0, -dx), w + min(0, -dx))
    out[ys, xs] = mask[yt, xt]
    return out


NEIGHBOURS = [(-1, 0), (1, 0), (0, -1), (0, 1)]


def dilate(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    out = mask
    for _ in range(steps):
        grown = out.copy()
        for dy, dx in NEIGHBOURS:
            grown |= shift(out, dy, dx)
        out = grown
    return out


def erode(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    out = mask
    for _ in range(steps):
        shrunk = out.copy()
        for dy, dx in NEIGHBOURS:
            shrunk &= shift(out, dy, dx)
        out = shrunk
    return out


def value_noise(height: int, width: int, cells: int, seed: int) -> np.ndarray:
    """Smooth noise in roughly -1..1, from a coarse random grid bilinearly
    upsampled. Deterministic for a given seed so map builds are reproducible."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells + 1, cells * 2 + 1), dtype=np.float32) * 2.0 - 1.0
    ys = np.linspace(0, cells, height, dtype=np.float32)
    xs = np.linspace(0, cells * 2, width, dtype=np.float32)
    y0 = np.floor(ys).astype(np.int32)
    x0 = np.floor(xs).astype(np.int32)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    # Smoothstep the interpolant so the field shows no grid creases.
    fy = fy * fy * (3.0 - 2.0 * fy)
    fx = fx * fx * (3.0 - 2.0 * fx)
    y1 = np.minimum(y0 + 1, cells)
    x1 = np.minimum(x0 + 1, cells * 2)
    top = grid[np.ix_(y0, x0)] * (1 - fx) + grid[np.ix_(y0, x1)] * fx
    bottom = grid[np.ix_(y1, x0)] * (1 - fx) + grid[np.ix_(y1, x1)] * fx
    return top * (1 - fy) + bottom * fy


def fractal_noise(height: int, width: int, seed: int) -> np.ndarray:
    """Two octaves: a broad wander plus a little local roughness."""
    return (value_noise(height, width, 6, seed) * 0.7
            + value_noise(height, width, 17, seed + 1) * 0.3)


def latitude_bands(lod: Lod) -> np.ndarray:
    """Per-pixel land colour index from latitude, dithered at the boundaries so
    bands blend in pixel-art fashion instead of banding as hard stripes."""
    rows = np.arange(lod.height, dtype=np.float32)
    lat = 90.0 - (rows + 0.5) / lod.height * 180.0
    abs_lat = np.abs(lat)[:, None]
    dither = np.tile(BAYER4, (lod.height // 4 + 1, lod.width // 4 + 1))
    dither = dither[:lod.height, :lod.width]
    # Coherent noise bends each boundary into an organic shape; the ordered
    # dither then stipples the last couple of degrees so the seam reads as a
    # pixel-art transition rather than a hard edge.
    wander = fractal_noise(lod.height, lod.width, seed=20260826) * BAND_NOISE_DEGREES
    jittered = abs_lat + wander + (dither - 0.5) * BAND_DITHER_DEGREES
    # Assign warmest first, then let colder bands overwrite, so each pixel ends
    # up in the coldest band whose bound it clears.
    index = np.zeros((lod.height, lod.width), dtype=np.uint8)
    index[:] = len(LAT_BANDS) - 1
    for band_index in range(len(LAT_BANDS) - 1, -1, -1):
        bound = LAT_BANDS[band_index][0]
        index[jittered >= bound] = band_index
    # Antarctica is ice all the way to the coast. The northern ice bound has to
    # sit high enough to keep Canada and Siberia habitable-looking, so the
    # southern cap is handled explicitly rather than by latitude alone.
    index[(lat < -63.0)[:, None].repeat(lod.width, axis=1)] = 0
    return index


def bayer(height: int, width: int, size: int = 4) -> np.ndarray:
    """Tiled ordered-dither threshold field in 0..1."""
    base = BAYER4 if size == 4 else np.array([[0, 2], [3, 1]], dtype=np.float32) / 4.0
    tiled = np.tile(base, (height // base.shape[0] + 1, width // base.shape[1] + 1))
    return tiled[:height, :width]


def dither_mix(rgb_buffer: np.ndarray, mask: np.ndarray, colour: str,
               shade: str, amount: float, field: np.ndarray) -> None:
    """Fill `mask` with `colour`, stippling `shade` in at `amount` coverage.

    Two palette colours in an ordered pattern instead of one blended colour:
    the result stays inside the palette and reads as deliberate pixel shading.
    """
    rgb_buffer[mask] = rgb(colour)
    stipple = mask & (field < amount)
    rgb_buffer[stipple] = rgb(shade)


def render(lod: Lod) -> Image.Image:
    print(f"[{lod.name}] {lod.width}x{lod.height}")
    land = polygon_mask(fetch(lod.land_src)["features"], lod)
    print(f"[{lod.name}]   land pixels: {int(land.sum()):,}")

    field = bayer(lod.height, lod.width)
    rgb_buffer = np.zeros((lod.height, lod.width, 3), dtype=np.uint8)
    rgb_buffer[:] = rgb(OCEAN_DEEP)

    # Shelf and open-ocean rings separate land from deep water without relying
    # on the coastline outline to do all the work.
    shelf = dilate(land, lod.shelf_px) & ~land
    open_ocean = dilate(land, lod.shelf_px * 3) & ~land & ~shelf
    dither_mix(rgb_buffer, open_ocean, OCEAN, OCEAN_DEEP, 0.35, field)
    rgb_buffer[shelf] = rgb(SHELF)

    # Land colour by latitude band, with the interior stippled darker.
    band_index = latitude_bands(lod)
    interior = erode(land, max(2, lod.shelf_px * 2))
    deep_interior = erode(interior, max(3, lod.shelf_px * 3))
    # Dither coverage is modulated by low-frequency noise rather than being a
    # constant. A constant produces a uniform crosshatch across every landmass,
    # which reads as screen noise; varying it produces patches of lighter and
    # darker ground, which reads as terrain.
    variation = fractal_noise(lod.height, lod.width, seed=771)
    interior_amount = np.clip((0.16 + variation * 0.20) * lod.dither_scale, 0.0, 0.6)
    deep_amount = np.clip((0.30 + variation * 0.26) * lod.dither_scale, 0.0, 0.8)
    for index, (_bound, key) in enumerate(LAT_BANDS):
        in_band = land & (band_index == index)
        rgb_buffer[in_band] = rgb(key)
        shade = BAND_SHADE.get(key, key)
        if shade != key:
            rgb_buffer[in_band & interior & (field < interior_amount)] = rgb(shade)
            rgb_buffer[in_band & deep_interior & (field < deep_amount)] = rgb(shade)

    if lod.lakes:
        lakes = polygon_mask(fetch(lod.lakes)["features"], lod) & land
        rgb_buffer[lakes] = rgb(LAKE)
        land = land & ~lakes

    # Borders are stippled rather than blended, so they read as a hint at a line
    # without introducing an off-palette colour.
    if lod.borders:
        borders = line_mask(fetch(lod.borders)["features"], lod, lod.simplify_px) & land
        rgb_buffer[borders & (field < 0.55)] = rgb(BORDER)
    if lod.states:
        states = line_mask(fetch(lod.states)["features"], lod, lod.simplify_px) & land
        rgb_buffer[states & (field < 0.28)] = rgb(BORDER)

    # Coastline last so nothing overdraws it: a hard 1 px outline, with the
    # north-west facing edge catching the light.
    edge = land & ~erode(land, 1)
    lit = edge & ~shift(land, -1, -1)
    rgb_buffer[edge] = rgb(COAST)
    rgb_buffer[lit] = rgb(COAST_LIT)

    used = {tuple(int(v) for v in c) for c in np.unique(rgb_buffer.reshape(-1, 3), axis=0)}
    stray = used - ALLOWED_RGB
    if stray:
        swatches = ", ".join("#%02x%02x%02x" % c for c in sorted(stray))
        raise SystemExit(f"{lod.name}: colours outside the locked palette: {swatches}")

    return Image.fromarray(rgb_buffer).convert("RGBA")


def main() -> None:
    ART_OUT.mkdir(parents=True, exist_ok=True)
    DATA_OUT.mkdir(parents=True, exist_ok=True)

    meta = {
        "generated_by": "tools/build_world_geometry.py",
        "source": "Natural Earth (public domain) via nvkelso/natural-earth-vector",
        "projection": "equirectangular",
        "world_units": {"width": 2048, "height": 1024},
        "note": "colours come from the locked palette in tools/pixelart/palette.py",
        "lods": [],
    }

    for lod in LODS:
        image = render(lod)
        out_path = ART_OUT / f"world_{lod.name}.png"
        image.save(out_path, optimize=True)
        size_kb = out_path.stat().st_size / 1024.0
        print(f"[{lod.name}] wrote {out_path.relative_to(ROOT)} ({size_kb:,.0f} KB)")
        meta["lods"].append({
            "name": lod.name,
            "texture": f"res://assets/art/world/world_{lod.name}.png",
            "width": lod.width,
            "height": lod.height,
            "source_layer": lod.land_src,
            "world_scale": 2048 / lod.width,
        })

    (DATA_OUT / "world_meta.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(f"wrote {(DATA_OUT / 'world_meta.json').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
