#!/usr/bin/env python3
"""Composes airport scenes from curated airfield crops.

Output: assets/art/production/airports/scenes/<id>.png plus the matching
geometry (runway line, taxi routes, stands, walker door) which is merged into
data/airport_layouts.json. The scene is the ground truth; the engine draws it
as one texture and animates aircraft, people and weather on top.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "art" / "production" / "airfield"
OUT = ROOT / "assets" / "art" / "production" / "airports" / "scenes"


def piece(name: str, rotate: int = 0, flip: bool = False) -> Image.Image:
    image = Image.open(ART / f"{name}.png").convert("RGBA")
    if flip:
        image = image.transpose(Image.FLIP_LEFT_RIGHT)
    if rotate:
        image = image.rotate(rotate, expand=True)
    return image


def tile_fill(canvas: Image.Image, name: str) -> None:
    tile = piece(name)
    for y in range(0, canvas.height, tile.height):
        for x in range(0, canvas.width, tile.width):
            canvas.alpha_composite(tile, (x, y))


def hstrip(canvas: Image.Image, name: str, x0: int, x1: int, y: int,
           rotate: int = 0) -> None:
    tile = piece(name, rotate)
    x = x0
    while x < x1:
        canvas.alpha_composite(tile.crop((0, 0, min(tile.width, x1 - x), tile.height)), (x, y))
        x += tile.width


def compose_bzn() -> tuple[Image.Image, dict]:
    W, H = 1600, 900
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tile_fill(canvas, "grass")

    # --- Runway: west threshold + plain mid segments + east threshold. -----
    # rotate(-90) lays the vertical strip horizontally with its numbers facing
    # the west approach; the east half rotates the other way so its numbers
    # face the east approach — no mirrored text, no centre seam.
    # Each sheet lane is a complete runway with thresholds at BOTH ends, so a
    # long runway is: the west half of one lane + dash fill + the east half of
    # the other. No phantom mid-field thresholds.
    lane_a = piece("runway_full_36L", rotate=-90)
    lane_b = piece("runway_full_18R", rotate=90)
    west = lane_a.crop((0, 0, 192, 96))
    east = lane_b.crop((192, 0, 384, 96))
    mid = lane_a.crop((150, 0, 190, 96))
    runway_y = 660
    rx = 200
    canvas.alpha_composite(west, (rx, runway_y))
    x = rx + west.width
    for _ in range(10):
        canvas.alpha_composite(mid, (x, runway_y))
        x += mid.width
    canvas.alpha_composite(east, (x, runway_y))
    runway_end_x = x + east.width

    # --- Taxiways: verticals from apron down to the runway edge, with a
    # horizontal hold bar just above the runway. ------------------------------
    taxi = piece("taxiway_lit")
    hold = piece("hold_dashed")
    for taxi_x in (520, 960):
        # Runs a few pixels onto the runway shoulder so no grass seam can show.
        canvas.alpha_composite(taxi.crop((0, 0, 96, runway_y - 430)), (taxi_x, 438))
        canvas.alpha_composite(hold.crop((0, 24, 96, 72)), (taxi_x, runway_y - 52))

    # --- Apron with painted bays, two blocks, no mirrored text. -------------
    apron = piece("apron_bays")
    canvas.alpha_composite(apron, (500, 150))
    canvas.alpha_composite(apron, (788, 150))

    # --- Terminal band sitting on its walkway. -------------------------------
    roof = piece("roof_vent_wide")
    glass = piece("terminal_glass_low")
    doors = piece("terminal_doors")
    tx, t_top = 500, 22
    glass_y = t_top + roof.height - 14
    for i in range(3):
        canvas.alpha_composite(glass, (tx + i * glass.width, glass_y))
    canvas.alpha_composite(doors, (tx + glass.width + 24, glass_y + glass.height - doors.height))
    x = tx
    while x < tx + 3 * glass.width:
        canvas.alpha_composite(roof, (x, t_top))
        x += roof.width
    canvas.alpha_composite(piece("sign_terminal"), (tx + 10, glass_y + 6))
    # Walkway runs continuously from the terminal to the apron edge.
    walk = piece("pavers")
    for wy in range(glass_y + glass.height, 152, 24):
        hstrip(canvas, "pavers", tx, tx + 3 * glass.width, wy)

    # --- Support buildings and a concrete service pad. -----------------------
    canvas.alpha_composite(piece("tower_plain"), (1180, 20))
    canvas.alpha_composite(piece("office_green"), (1200, 190))
    # Service area sits by the runway's west end where the eye passes it during
    # taxi, grouped on its own concrete pad.
    pad = piece("concrete")
    canvas.alpha_composite(pad, (120, 452))
    canvas.alpha_composite(pad, (120, 548))
    canvas.alpha_composite(piece("hangar_grey"), (140, 330))
    canvas.alpha_composite(piece("fuel_tank_round"), (128, 458))
    canvas.alpha_composite(piece("fuel_truck_side"), (170, 560))
    canvas.alpha_composite(piece("stairs_side"), (240, 470))

    # --- Dressing on the apron. ----------------------------------------------
    canvas.alpha_composite(piece("tug_train"), (620, 452))
    canvas.alpha_composite(piece("truck_cargo"), (1010, 456))
    for pole_x in (470, 1090):
        canvas.alpha_composite(piece("light_pole"), (pole_x, 150))
    canvas.alpha_composite(piece("sign_gate"), (466, 440))
    canvas.alpha_composite(piece("grate"), (760, 470))

    # --- Geometry (scene pixels; the engine subtracts the centre offset). ----
    cx, cy = W // 2, H // 2
    def pt(x, y): return [x - cx, y - cy]
    runway_c = runway_y + 48
    geometry = {
        "scene": "airports/scenes/bzn.png",
        "ground_extent": [W, H],
        "camera_focus": pt(780, 290),
        "runway": {"start": pt(rx + 20, runway_c), "end": pt(runway_end_x - 20, runway_c),
                   "width": 96, "designations": ["36L", "18R"]},
        "stands": [
            {"id": "stand_1", "position": pt(700, 300), "heading": -90, "size": "small"},
            {"id": "stand_2", "position": pt(1020, 300), "heading": -90, "size": "small"},
        ],
        "terminal_door": pt(770, 130),
        "ground": {
            "threshold": pt(rx + 90, runway_c), "rotate_at": pt(runway_end_x - 260, runway_c),
            "runway_end": pt(runway_end_x - 40, runway_c), "touchdown": pt(rx + 210, runway_c),
            "exit_at": pt(1008, runway_c),
            "stands": {
                "stand_1": {
                    "pushback": [pt(700, 300), pt(700, 400)],
                    "taxi_out": [pt(700, 400), pt(568, 470), pt(568, 600),
                                 pt(430, runway_c), pt(rx + 90, runway_c)],
                    "taxi_in": [pt(1008, runway_c), pt(1008, 560), pt(1008, 470),
                                pt(730, 430), pt(700, 380), pt(700, 300)],
                },
                "stand_2": {
                    "pushback": [pt(1020, 300), pt(1020, 400)],
                    "taxi_out": [pt(1020, 400), pt(1008, 470), pt(568, 600),
                                 pt(430, runway_c), pt(rx + 90, runway_c)],
                    "taxi_in": [pt(1008, runway_c), pt(1008, 520), pt(1020, 440),
                                pt(1020, 380), pt(1020, 300)],
                },
            },
        },
    }
    return canvas, geometry


def merge_layout(airport_layout_id: str, geometry: dict) -> None:
    path = ROOT / "data" / "airport_layouts.json"
    data = json.loads(path.read_text())
    for layout in data["layouts"]:
        if layout["id"] != airport_layout_id:
            continue
        layout["scene"] = geometry["scene"]
        layout["ground_extent"] = geometry["ground_extent"]
        layout["camera_focus"] = geometry["camera_focus"]
        layout["runway"] = geometry["runway"]
        layout["stands"] = geometry["stands"]
        layout["terminal_door"] = geometry["terminal_door"]
        layout["ground"] = geometry["ground"]
        # Procedural-only keys are gone on scene airports; leaving them invites
        # exactly the stale-fallback confusion that hid the scene last time.
        for stale in ("secondary_runways", "apron", "taxiways", "buildings",
                      "decor", "props", "fence", "service_points"):
            layout.pop(stale, None)
    path.write_text(json.dumps(data, indent=2) + "\n")


def compose_bil() -> tuple[Image.Image, dict]:
    """BIL: the same vocabulary, one size down — single apron block, no tower,
    a warehouse instead of a hangar, prairie feel."""
    W, H = 1400, 820
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tile_fill(canvas, "grass")

    lane_a = piece("runway_full_36L", rotate=-90)
    lane_b = piece("runway_full_18R", rotate=90)
    west = lane_a.crop((0, 0, 192, 96))
    east = lane_b.crop((192, 0, 384, 96))
    mid = lane_a.crop((150, 0, 190, 96))
    runway_y = 600
    rx = 170
    canvas.alpha_composite(west, (rx, runway_y))
    x = rx + west.width
    for _ in range(8):
        canvas.alpha_composite(mid, (x, runway_y))
        x += mid.width
    canvas.alpha_composite(east, (x, runway_y))
    runway_end_x = x + east.width

    taxi = piece("taxiway_lit")
    hold = piece("hold_dashed")
    taxi_x = 640
    canvas.alpha_composite(taxi.crop((0, 0, 96, runway_y - 380)), (taxi_x, 388))
    canvas.alpha_composite(hold.crop((0, 24, 96, 72)), (taxi_x, runway_y - 52))

    apron = piece("apron_bays")
    canvas.alpha_composite(apron, (520, 100))
    hstrip(canvas, "pavers", 520, 808, 70)

    roof = piece("roof_vent_wide")
    glass = piece("terminal_glass_low")
    doors = piece("terminal_doors")
    tx, t_top = 520, -20
    glass_y = t_top + roof.height - 14
    canvas.alpha_composite(glass, (tx, glass_y))
    canvas.alpha_composite(doors, (tx + glass.width - 30, glass_y + glass.height - doors.height))
    x2 = tx
    while x2 < tx + glass.width + doors.width - 30:
        canvas.alpha_composite(roof, (x2, t_top))
        x2 += roof.width
    canvas.alpha_composite(piece("sign_terminal"), (tx + 10, glass_y + 8))

    canvas.alpha_composite(piece("office_green"), (1050, 90))
    canvas.alpha_composite(piece("fuel_tank_round"), (1070, 240))
    canvas.alpha_composite(piece("truck_cargo"), (860, 380))
    canvas.alpha_composite(piece("tug_blue"), (620, 330))
    canvas.alpha_composite(piece("light_pole"), (500, 96))
    canvas.alpha_composite(piece("light_pole"), (830, 96))

    cx, cy = W // 2, H // 2
    def pt(x3, y3): return [x3 - cx, y3 - cy]
    runway_c = runway_y + 48
    geometry = {
        "scene": "airports/scenes/bil.png",
        "ground_extent": [W, H],
        "camera_focus": pt(680, 260),
        "runway": {"start": pt(rx + 20, runway_c), "end": pt(runway_end_x - 20, runway_c),
                   "width": 96, "designations": ["36L", "18R"]},
        "stands": [
            {"id": "stand_1", "position": pt(640, 240), "heading": -90, "size": "small"},
            {"id": "stand_2", "position": pt(760, 240), "heading": -90, "size": "small"},
        ],
        "terminal_door": pt(640, 80),
        "ground": {
            "threshold": pt(rx + 90, runway_c), "rotate_at": pt(runway_end_x - 240, runway_c),
            "runway_end": pt(runway_end_x - 40, runway_c), "touchdown": pt(rx + 190, runway_c),
            "exit_at": pt(taxi_x + 48, runway_c),
            "stands": {
                "stand_1": {
                    "pushback": [pt(640, 240), pt(640, 340)],
                    "taxi_out": [pt(640, 340), pt(688, 400), pt(688, 540),
                                 pt(420, runway_c), pt(rx + 90, runway_c)],
                    "taxi_in": [pt(taxi_x + 48, runway_c), pt(688, 520), pt(688, 400),
                                pt(640, 340), pt(640, 240)],
                },
                "stand_2": {
                    "pushback": [pt(760, 240), pt(760, 340)],
                    "taxi_out": [pt(760, 340), pt(688, 400), pt(688, 540),
                                 pt(420, runway_c), pt(rx + 90, runway_c)],
                    "taxi_in": [pt(taxi_x + 48, runway_c), pt(688, 520), pt(688, 400),
                                pt(760, 340), pt(760, 240)],
                },
            },
        },
    }
    return canvas, geometry


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    scene, geometry = compose_bzn()
    scene.save(OUT / "bzn.png")
    (OUT / "bzn.png.import").unlink(missing_ok=True)
    merge_layout("layout_bzn", geometry)
    print("bzn scene:", scene.size)
    scene, geometry = compose_bil()
    scene.save(OUT / "bil.png")
    (OUT / "bil.png.import").unlink(missing_ok=True)
    merge_layout("layout_bil", geometry)
    print("bil scene:", scene.size)
