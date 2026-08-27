#!/usr/bin/env python3
"""Slices curated library sheets into named production assets.

    python3 tools/curate.py            # extract everything in MANIFEST
    python3 tools/curate.py grid <sheet-path> [scale]   # numbered grid overlay

Every extraction is an explicit crop in MANIFEST — sheet, rect, destination —
so the art that ships is reviewable and re-runnable, and nothing is hand-copied
into the tree. Destinations are logical paths under assets/art/production/,
which the AssetPaths resolver serves ahead of any placeholder automatically.

The library keeps its own palette: these are approved finished assets, not
pipeline drawings, so they are NOT snapped to the game palette. The pixel style
guide's palette rule applies to generated placeholder art.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
LIB = ROOT / "assets" / "library" / "PixelSkies_Curated_Assets"
OUT = ROOT / "assets" / "art" / "production"

def _load_manifests() -> dict:
    """Merge every tools/curation/*.py domain manifest."""
    import importlib
    merged: dict[str, list] = {}
    for module_file in sorted((ROOT / "tools" / "curation").glob("*.py")):
        if module_file.stem.startswith("_"):
            continue
        module = importlib.import_module(f"curation.{module_file.stem}")
        for sheet, crops in getattr(module, "MANIFEST", {}).items():
            merged.setdefault(sheet, []).extend(crops)
    return merged


MANIFEST: dict[str, list[tuple[int, int, int, int, str]]] = {}


def extract() -> int:
    MANIFEST.update(_load_manifests())
    count = 0
    for sheet_rel, crops in MANIFEST.items():
        sheet = Image.open(LIB / sheet_rel).convert("RGBA")
        for x, y, w, h, dest in crops:
            piece = sheet.crop((x, y, x + w, y + h))
            target = OUT / dest
            target.parent.mkdir(parents=True, exist_ok=True)
            piece.save(target)
            # A stale Godot import of a previous file at this path would keep
            # serving the old texture; clear it so the reimport is clean.
            stale = target.with_suffix(".png.import")
            if stale.exists():
                stale.unlink()
            count += 1
    print(f"extracted {count} assets from {len(MANIFEST)} sheets")
    return count


def grid(sheet_path: str, scale: int = 1) -> None:
    """Writes a numbered 48px-grid overlay next to the sheet for crop picking."""
    src = Path(sheet_path)
    image = Image.open(src).convert("RGBA")
    if scale > 1:
        image = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(image)
    step = 48 * scale
    for x in range(0, image.width, step):
        draw.line([(x, 0), (x, image.height)], fill=(255, 0, 255, 120))
        draw.text((x + 2, 2), str(x // scale), fill=(255, 0, 255, 255))
    for y in range(0, image.height, step):
        draw.line([(0, y), (image.width, y)], fill=(255, 0, 255, 120))
        draw.text((2, y + 2), str(y // scale), fill=(255, 0, 255, 255))
    out = src.with_name(src.stem + "_grid.png")
    image.save(out)
    print(out)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "grid":
        grid(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 1)
    else:
        extract()
