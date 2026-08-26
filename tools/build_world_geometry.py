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

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".ne_cache"
ART_OUT = ROOT / "assets" / "art" / "world"
DATA_OUT = ROOT / "data" / "world"

BASE_URL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"

# ---------------------------------------------------------------------------
# Palette. One controlled palette for the whole world map, per docs/ART_BIBLE.md.
# Light direction is upper-left, so coasts get a light NW rim and a dark SE rim.
# ---------------------------------------------------------------------------
PALETTE = {
    "ocean_deep":    (0x0f, 0x24, 0x35),
    "ocean":         (0x17, 0x36, 0x4a),
    "ocean_shelf":   (0x21, 0x4c, 0x63),
    "coast_dark":    (0x0b, 0x1a, 0x25),
    "coast_light":   (0x86, 0xa9, 0x9b),
    "ice":           (0xd3, 0xe2, 0xe8),
    "tundra":        (0x64, 0x74, 0x69),
    "boreal":        (0x3d, 0x5a, 0x45),
    "temperate":     (0x53, 0x6c, 0x54),
    "steppe":        (0x67, 0x76, 0x51),
    "arid":          (0x7d, 0x78, 0x53),
    "tropical":      (0x3f, 0x66, 0x42),
    "lake":          (0x1d, 0x44, 0x5c),
    "border":        (0x2f, 0x3f, 0x3a),
}

# Latitude colour bands, stylized rather than climatological: a readable
# flat-lay map look. (abs_lat_upper_bound, palette_key)
LAT_BANDS = [
    (72.0, "ice"),
    (60.0, "tundra"),
    (50.0, "boreal"),
    (34.0, "temperate"),
    (20.0, "arid"),
    (10.0, "steppe"),
    (0.0, "tropical"),
]

# How far a band boundary may wander, in degrees of latitude. Straight
# horizontal colour changes across a continent look like a gradient overlay
# rather than terrain, so boundaries are displaced by coherent noise.
BAND_NOISE_DEGREES = 9.0
# Width of the stippled transition either side of a boundary.
BAND_DITHER_DEGREES = 2.5

BAYER4 = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
], dtype=np.float32) / 16.0


class Lod:
    def __init__(self, name, width, height, land_src, simplify_px,
                 min_area_px, shelf_px, lakes, borders, states):
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


# Three tiers, sized so each one displays at an integer scale at a camera zoom
# stop (see docs/WORLD_MAP_AND_ZOOM.md). World space is 4096x2048 units, so lod0
# draws at 4x, lod1 at 2x and lod2 at 1x — no fractional texel sampling, which
# is what keeps pixel art from shimmering while zooming.
LODS = [
    Lod("lod0", 1024, 512, "ne_110m_land", 0.9, 5.0, 2,
        lakes=None, borders=None, states=None),
    Lod("lod1", 2048, 1024, "ne_110m_land", 0.75, 6.0, 3,
        lakes="ne_50m_lakes", borders="ne_110m_admin_0_boundary_lines_land", states=None),
    Lod("lod2", 4096, 2048, "ne_50m_land", 0.6, 8.0, 4,
        lakes="ne_50m_lakes", borders="ne_50m_admin_0_boundary_lines_land",
        states="ne_50m_admin_1_states_provinces_lines"),
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


def render(lod: Lod) -> Image.Image:
    print(f"[{lod.name}] {lod.width}x{lod.height}")
    land = polygon_mask(fetch(lod.land_src)["features"], lod)
    print(f"[{lod.name}]   land pixels: {int(land.sum()):,}")

    rgb = np.zeros((lod.height, lod.width, 3), dtype=np.uint8)
    rgb[:] = PALETTE["ocean_deep"]

    # Continental shelf ring: reads as shallow water and separates land from the
    # deep ocean without an outline doing all the work.
    shelf = dilate(land, lod.shelf_px) & ~land
    open_ocean = dilate(land, lod.shelf_px * 3) & ~land & ~shelf
    rgb[open_ocean] = PALETTE["ocean"]
    rgb[shelf] = PALETTE["ocean_shelf"]

    # Land colour by latitude band.
    band_index = latitude_bands(lod)
    for index, (_bound, key) in enumerate(LAT_BANDS):
        rgb[land & (band_index == index)] = PALETTE[key]

    # Interior shading: pixels far from any coast darken slightly, giving the
    # landmasses depth without a lighting pass.
    interior = erode(land, max(2, lod.shelf_px * 2))
    deep_interior = erode(interior, max(3, lod.shelf_px * 3))
    rgb[interior] = (rgb[interior].astype(np.int16) * 0.93).astype(np.uint8)
    rgb[deep_interior] = (rgb[deep_interior].astype(np.int16) * 0.93).astype(np.uint8)

    if lod.lakes:
        lakes = polygon_mask(fetch(lod.lakes)["features"], lod) & land
        rgb[lakes] = PALETTE["lake"]
        land = land & ~lakes

    if lod.borders:
        borders = line_mask(fetch(lod.borders)["features"], lod, lod.simplify_px) & land
        blended = rgb[borders].astype(np.int16) * 0.55 + np.array(PALETTE["border"]) * 0.45
        rgb[borders] = blended.astype(np.uint8)

    if lod.states:
        states = line_mask(fetch(lod.states)["features"], lod, lod.simplify_px) & land
        # State hints are deliberately fainter than country borders.
        blended = rgb[states].astype(np.int16) * 0.78 + np.array(PALETTE["border"]) * 0.22
        rgb[states] = blended.astype(np.uint8)

    # Coastline last so nothing overdraws it. Upper-left light: the NW-facing
    # edge catches light, the rest of the outline stays dark.
    edge = land & ~erode(land, 1)
    lit = edge & ~shift(land, -1, -1)
    rgb[edge] = PALETTE["coast_dark"]
    rgb[lit & edge] = PALETTE["coast_light"]

    image = Image.fromarray(rgb).convert("RGBA")
    return image


def main() -> None:
    ART_OUT.mkdir(parents=True, exist_ok=True)
    DATA_OUT.mkdir(parents=True, exist_ok=True)

    meta = {
        "generated_by": "tools/build_world_geometry.py",
        "source": "Natural Earth (public domain) via nvkelso/natural-earth-vector",
        "projection": "equirectangular",
        "world_units": {"width": 4096, "height": 2048},
        "palette": {k: "#%02x%02x%02x" % v for k, v in PALETTE.items()},
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
            "world_scale": 4096 // lod.width,
        })

    (DATA_OUT / "world_meta.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(f"wrote {(DATA_OUT / 'world_meta.json').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
