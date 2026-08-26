#!/usr/bin/env python3
"""Regenerates every Pixel Skies sprite, tile, frame and font.

    python3 tools/build_pixel_assets.py

Assets are code, not binaries someone hand-edited: restyling the game is a
re-run of this script. Everything is validated against docs/PIXEL_STYLE_GUIDE.md
before it is written — palette conformance and binary alpha are enforced by
Canvas.save, so a broken asset fails the build rather than shipping.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pixelart import font_build, scenery, ui                      # noqa: E402
from pixelart.aircraft import (SPECS, build_map_rotation_strip,    # noqa: E402
                               build_rotation_strip, build_side, build_top)
from pixelart.palette import PALETTE                              # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "art"
DATA = ROOT / "data"


def build_aircraft() -> int:
    count = 0
    for key, spec in SPECS.items():
        folder = ART / "aircraft" / key
        build_top(spec).save(folder / f"{key}_top.png", f"{key}_top")
        build_side(spec).save(folder / f"{key}_side.png", f"{key}_side")
        build_rotation_strip(spec).save(folder / f"{key}_top_rot.png", f"{key}_top_rot")
        build_map_rotation_strip(spec).save(folder / f"{key}_map_rot.png", f"{key}_map_rot")
        count += 4
    return count


def build_tiles() -> int:
    folder = ART / "airports" / "tiles"
    for name, factory in scenery.SURFACE_TILES.items():
        factory().save(folder / f"{name}.png", name)
    return len(scenery.SURFACE_TILES)


def build_buildings() -> int:
    folder = ART / "airports" / "buildings"
    for name, factory in scenery.BUILDINGS.items():
        factory().save(folder / f"{name}.png", name)
    return len(scenery.BUILDINGS)


def build_vehicles() -> int:
    folder = ART / "airports" / "vehicles"
    for name, factory in scenery.VEHICLES.items():
        factory().save(folder / f"{name}.png", name)
    props = ART / "airports" / "props"
    for name, factory in scenery.PROPS.items():
        factory().save(props / f"{name}.png", name)
    return len(scenery.VEHICLES) + len(scenery.PROPS)


def build_people_and_cargo() -> int:
    people = ART / "people"
    shirts = {
        "traveller_teal": "accent_teal",
        "traveller_orange": "accent_orange",
        "traveller_red": "accent_red",
        "traveller_green": "accent_green",
        "traveller_grey": "metal",
    }
    for name, shirt in shirts.items():
        scenery.passenger(shirt).save(people / f"{name}.png", name)
    cargo = ART / "cargo"
    for kind in ("box", "mail", "medical", "livestock"):
        scenery.crate(kind).save(cargo / f"crate_{kind}.png", kind)
    return len(shirts) + 4


def build_ui() -> int:
    folder = ART / "ui"
    for name, factory in ui.FRAMES.items():
        factory().save(folder / f"{name}.png", name)
    for name, factory in ui.ICONS.items():
        factory().save(folder / "icons" / f"{name}.png", name)
    for name, factory in ui.MARKERS.items():
        factory().save(ART / "world" / f"{name}.png", name)
    font_build.write(folder)
    return len(ui.FRAMES) + len(ui.ICONS) + len(ui.MARKERS) + 1


def export_palette() -> None:
    """The engine reads the same palette the art was built from, so UI colours
    can never drift away from the sprites."""
    target = DATA / "world" / "palette.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({"palette": PALETTE}, indent=2) + "\n")


def main() -> None:
    total = 0
    for label, step in (
        ("aircraft", build_aircraft),
        ("surface tiles", build_tiles),
        ("buildings", build_buildings),
        ("vehicles", build_vehicles),
        ("people and cargo", build_people_and_cargo),
        ("ui", build_ui),
    ):
        count = step()
        total += count
        print(f"  {label:>18}: {count}")
    export_palette()
    print(f"wrote {total} assets, all validated against the style guide")


if __name__ == "__main__":
    main()
