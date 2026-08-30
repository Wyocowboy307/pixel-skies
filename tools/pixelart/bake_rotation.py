#!/usr/bin/env python3
"""Bake heading-rotation strips from a production top-view sprite.

The placeholder pipeline plots every heading procedurally, but a production
top view (generated art, approved by eye) exists only as one nose-east PNG.
Rotating pixel art naively at arbitrary angles shreds its edges, so each frame
here is produced by supersampling 6x (nearest), rotating, then reducing each
6x6 block to its modal opaque colour — which keeps flat fills flat and edges
hard — and finally snapping any stray colour back to the sprite's own set.

Frame 0 points east (+x); frames advance clockwise in screen space, matching
tools/pixelart/aircraft.py build_rotation_strip and AircraftSprites.frame_for.

Usage:
    python3 tools/pixelart/bake_rotation.py <top.png> <out_strip.png> [frames]
    python3 tools/pixelart/bake_rotation.py --all    # every production family
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
PRODUCTION = ROOT / "assets" / "art" / "production" / "aircraft"
FRAMES = 32
SUPER = 6


def _mode_reduce(im: Image.Image, k: int) -> Image.Image:
    out = Image.new("RGBA", (im.width // k, im.height // k), (0, 0, 0, 0))
    src = im.load()
    dst = out.load()
    for y in range(out.height):
        for x in range(out.width):
            opaque = []
            for dy in range(k):
                for dx in range(k):
                    p = src[x * k + dx, y * k + dy]
                    if p[3] >= 128:
                        opaque.append((p[0], p[1], p[2], 255))
            if len(opaque) * 2 >= k * k:
                dst[x, y] = Counter(opaque).most_common(1)[0][0]
    return out


def _snap_to_own_colours(im: Image.Image, colours: set) -> Image.Image:
    im = im.copy()
    px = im.load()
    table = list(colours)
    cache: dict = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0 or (r, g, b) in colours:
                continue
            if (r, g, b) not in cache:
                cache[(r, g, b)] = min(
                    table, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            n = cache[(r, g, b)]
            px[x, y] = (n[0], n[1], n[2], 255)
    return im


def bake(top_path: Path, out_path: Path, frames: int = FRAMES) -> None:
    source = Image.open(top_path).convert("RGBA")
    size = source.width
    if source.height != size:
        raise SystemExit(f"{top_path}: top view must be square, got {source.size}")
    own = {p[:3] for _, p in source.getcolors(99999) if p[3] == 255}
    big = source.resize((size * SUPER, size * SUPER), Image.NEAREST)
    strip = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
    for index in range(frames):
        degrees = -index * (360.0 / frames)
        rotated = big.rotate(degrees, resample=Image.NEAREST, expand=False)
        frame = _snap_to_own_colours(_mode_reduce(rotated, SUPER), own)
        strip.paste(frame, (index * size, 0))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out_path)
    stale = out_path.with_suffix(out_path.suffix + ".import")
    if stale.exists():
        stale.unlink()
    print(f"baked {out_path.relative_to(ROOT)} ({frames}x{size}px)")


def main(argv: list) -> int:
    if argv and argv[0] == "--all":
        for family_dir in sorted(PRODUCTION.iterdir()):
            if not family_dir.is_dir() or family_dir.name.startswith("_"):
                continue
            top = family_dir / f"{family_dir.name}_top.png"
            if top.exists():
                bake(top, family_dir / f"{family_dir.name}_top_rot.png")
        return 0
    if len(argv) < 2:
        print(__doc__)
        return 1
    bake(Path(argv[0]), Path(argv[1]), int(argv[2]) if len(argv) > 2 else FRAMES)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
