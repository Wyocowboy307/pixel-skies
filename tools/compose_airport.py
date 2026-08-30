#!/usr/bin/env python3
"""Composes airport scenes from curated airfield crops.

Output: assets/art/production/airports/scenes/<id>.png plus the matching
geometry (runway line, taxi routes, stands, walker door) which is merged into
data/airport_layouts.json. The scene is the ground truth; the engine draws it
as one texture and animates aircraft, people and weather on top.

Scale truth: a parked small plane is ~44px across. Aircraft stands are painted
here at that scale (56x64 boxes, amber lead-in, painted number) in the marking
language sampled from airport/5 — the library's own car-park stalls stay
landside where they belong.

Composition vocabulary shared by every airport:
  grass base with subtle mown stripes -> runway/taxiways -> concrete apron with
  painted stands + service lane -> terminal facade band on its paver walkway ->
  support buildings on connected concrete pads -> landside road, car park with
  cars, perimeter fence, greenery.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets" / "art" / "production" / "airfield"
TERRAIN = ROOT / "assets" / "art" / "production" / "world" / "terrain"
OUT = ROOT / "assets" / "art" / "production" / "airports" / "scenes"

# Marking colours sampled from the airport/5 sheet (runway numbers / stall
# paint white, taxiway centreline amber). Never invent new marking colours.
WHITE = (231, 232, 234, 255)
AMBER = (214, 178, 106, 255)
AMBER_DIM = (190, 155, 90, 255)
GREY_LINE = (168, 170, 168, 255)

_CACHE: dict[str, Image.Image] = {}


def piece(name: str, rotate: int = 0, flip: bool = False) -> Image.Image:
    key = f"{name}|{rotate}|{flip}"
    if key not in _CACHE:
        image = Image.open(ART / f"{name}.png").convert("RGBA")
        if flip:
            image = image.transpose(Image.FLIP_LEFT_RIGHT)
        if rotate:
            image = image.rotate(rotate, expand=True)
        _CACHE[key] = image
    return _CACHE[key]


def terrain(name: str) -> Image.Image:
    key = f"terrain/{name}"
    if key not in _CACHE:
        _CACHE[key] = Image.open(TERRAIN / f"{name}.png").convert("RGBA")
    return _CACHE[key]


def tile_rect(canvas: Image.Image, img: Image.Image,
              x0: int, y0: int, x1: int, y1: int) -> None:
    """Tiles img over the rect, cropping at the far edges."""
    y = y0
    while y < y1:
        x = x0
        h = min(img.height, y1 - y)
        while x < x1:
            w = min(img.width, x1 - x)
            canvas.alpha_composite(img.crop((0, 0, w, h)), (x, y))
            x += img.width
        y += img.height


def grass_base(canvas: Image.Image) -> None:
    """Library grass everywhere, then very subtle alternating mown bands so
    large fields read as tended ground instead of a flat fill."""
    tile_rect(canvas, piece("grass"), 0, 0, canvas.width, canvas.height)
    band = 64
    for i, y in enumerate(range(0, canvas.height, band)):
        if i % 2 == 0:
            continue
        y1 = min(y + band, canvas.height)
        region = canvas.crop((0, y, canvas.width, y1))
        canvas.paste(ImageEnhance.Brightness(region).enhance(0.965), (0, y))


# 3x5 digit bitmaps for painted stand numbers.
_DIGITS = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001010010010", "8": "111101111101111",
    "9": "111101111001111",
}


def draw_digits(dr: ImageDraw.ImageDraw, x: int, y: int, text: str,
                colour: tuple, scale: int = 2) -> None:
    for ch in text:
        bits = _DIGITS.get(ch)
        if bits is None:
            x += 4 * scale
            continue
        for row in range(5):
            for col in range(3):
                if bits[row * 3 + col] == "1":
                    dr.rectangle((x + col * scale, y + row * scale,
                                  x + col * scale + scale - 1,
                                  y + row * scale + scale - 1), fill=colour)
        x += 4 * scale


def stand_markings(canvas: Image.Image, cx: int, cy: int, number: int,
                   lane_y: int, size: str = "small") -> None:
    """One aircraft stand at plane scale: an open white box, an amber lead-in
    with a T-bar, and a painted stand number. The box is sized so a parked
    44px (small), 64px (medium) or 96px (large) aircraft sits inside with
    margin."""
    dr = ImageDraw.Draw(canvas)
    w, h = {"small": (56, 64), "medium": (76, 84), "large": (108, 116)}[size]
    x0, y0 = cx - w // 2, cy - h // 2
    x1, y1 = x0 + w, y0 + h
    # Three-sided box, open toward the taxi lane (south).
    dr.rectangle((x0, y0, x1, y0 + 1), fill=WHITE)              # top
    dr.rectangle((x0, y0, x0 + 1, y1 - 10), fill=WHITE)         # left
    dr.rectangle((x1 - 1, y0, x1, y1 - 10), fill=WHITE)         # right
    # Amber lead-in from the lane to the stop point, with a T-bar.
    dr.rectangle((cx - 1, cy + 4, cx, lane_y), fill=AMBER)
    dr.rectangle((cx - 7, cy + 3, cx + 6, cy + 4), fill=AMBER)  # T-bar
    # Painted number tucked into the top-left corner.
    draw_digits(dr, x0 + 5, y0 + 5, str(number), WHITE, 2)


def service_lane(canvas: Image.Image, x0: int, x1: int, y: int,
                 stop_xs: list[int] | None = None) -> None:
    """A GSE lane painted on the apron: two amber dashed edge lines 36px apart
    plus white stop bars where the lane meets taxi routes."""
    dr = ImageDraw.Draw(canvas)
    for line_y in (y, y + 36):
        x = x0
        while x < x1:
            dr.rectangle((x, line_y, min(x + 10, x1), line_y + 1),
                         fill=AMBER_DIM)
            x += 18
    for sx in (stop_xs or []):
        dr.rectangle((sx, y + 4, sx + 2, y + 32), fill=WHITE)


def runway_strip(canvas: Image.Image, rx: int, runway_y: int, mids: int) -> int:
    """West threshold + dash fill + east threshold; returns the end x."""
    lane_a = piece("runway_full_36L", rotate=-90)
    lane_b = piece("runway_full_18R", rotate=90)
    west = lane_a.crop((0, 0, 192, 96))
    east = lane_b.crop((192, 0, 384, 96))
    mid = lane_a.crop((150, 0, 190, 96))
    canvas.alpha_composite(west, (rx, runway_y))
    x = rx + west.width
    for _ in range(mids):
        canvas.alpha_composite(mid, (x, runway_y))
        x += mid.width
    canvas.alpha_composite(east, (x, runway_y))
    return x + east.width


def vtaxiway(canvas: Image.Image, x: int, y0: int, y1: int) -> None:
    """Vertical taxiway from the apron edge onto the runway shoulder, with the
    library hold-short bar band sitting just above the runway."""
    taxi = piece("taxiway_lit")
    tile_rect(canvas, taxi, x, y0, x + 96, y1)
    bars = piece("hold_bars")
    canvas.alpha_composite(bars, (x, y1 - bars.height - 6))


def terminal_band(canvas: Image.Image, tx: int, t_top: int,
                  seq: list[str]) -> tuple[int, int, int]:
    """Facade band: roof vents on top, glass/door pieces below, all bottoms on
    one line, the whole band grounded on pavers so the angled corner pieces
    never stand on raw grass. Returns (end_x, glass_y, bottom_y)."""
    roof = piece("roof_vent_wide")
    glass_y = t_top + roof.height - 14
    bottom = glass_y + 96
    x_end = tx + sum(piece(n).width for n in seq)
    tile_rect(canvas, piece("pavers"), tx - 8, glass_y, x_end + 8, bottom)
    x = tx
    for name in seq:
        img = piece(name)
        canvas.alpha_composite(img, (x, bottom - img.height))
        x += img.width
    rx = tx
    while rx < x_end:
        canvas.alpha_composite(roof.crop((0, 0, min(roof.width, x_end - rx),
                                          roof.height)), (rx, t_top))
        rx += roof.width
    return x_end, glass_y, bottom


def walkway(canvas: Image.Image, x0: int, x1: int, y0: int, y1: int) -> None:
    tile_rect(canvas, piece("pavers"), x0, y0, x1, y1)


def pad(canvas: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    tile_rect(canvas, piece("concrete"), x0, y0, x1, y1)


def car_park(canvas: Image.Image, x: int, y: int, cars: list[str],
             flip: bool = False) -> None:
    """A5 landside stall strip with library cars parked nose-in. Stall centres
    sit at fixed offsets inside the 288x96 crop."""
    strip = piece("car_park", rotate=180 if flip else 0)
    canvas.alpha_composite(strip, (x, y))
    slots = [27, 72, 123, 168, 220, 264]
    for i, name in enumerate(cars):
        if not name:
            continue
        car = piece(name, rotate=180 if flip else 0)
        sx = slots[i % len(slots)]
        if flip:
            sx = 288 - sx
        cy = y + 50 if flip else y + 2
        canvas.alpha_composite(car, (x + sx - car.width // 2, cy))


def fence_run(canvas: Image.Image, x0: int, x1: int, y: int) -> None:
    fence = piece("fence_gate")
    x = x0
    while x < x1:
        canvas.alpha_composite(fence.crop((0, 0, min(fence.width, x1 - x),
                                           fence.height)), (x, y))
        x += fence.width


def props(canvas: Image.Image, placements: list[tuple[str, int, int]]) -> None:
    for name, x, y in placements:
        canvas.alpha_composite(piece(name), (x, y))


def flora(canvas: Image.Image, placements: list[tuple[str, int, int]]) -> None:
    for name, x, y in placements:
        canvas.alpha_composite(terrain(name), (x, y))


def stand_routes(stands: list[tuple[str, int, int]], lane_y: int,
                 taxi_w_c: int, taxi_e_c: int, runway_c: int,
                 threshold_x: int, pt) -> dict:
    """The movement contract for every stand. pushback[0] == stand position;
    taxi_out ends at the threshold; taxi_in starts at exit_at (the east
    taxiway on the centreline) and ends exactly on the stand position."""
    routes = {}
    for sid, x, y in stands:
        routes[sid] = {
            "pushback": [pt(x, y), pt(x, lane_y)],
            "taxi_out": [pt(x, lane_y), pt(taxi_w_c, lane_y + 22),
                         pt(taxi_w_c, runway_c - 42), pt(taxi_w_c - 44, runway_c),
                         pt(threshold_x, runway_c)],
            "taxi_in": [pt(taxi_e_c, runway_c), pt(taxi_e_c, lane_y + 22),
                        pt(x + 40, lane_y + 4), pt(x, lane_y - 26), pt(x, y)],
        }
    return routes


# ---------------------------------------------------------------------------
# BZN — intimate mountain regional: pines, green office, two stands.
# ---------------------------------------------------------------------------

def compose_bzn() -> tuple[Image.Image, dict]:
    W, H = 1360, 800
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grass_base(canvas)

    # --- Airside groundwork. ---------------------------------------------
    runway_y = 680
    rx = 140
    runway_end_x = runway_strip(canvas, rx, runway_y, 17)
    runway_c = runway_y + 48

    apron = (440, 294, 1060, 620)
    pad(canvas, *apron)
    for taxi_x in (500, 940):
        vtaxiway(canvas, taxi_x, 620, runway_y + 8)

    # --- Terminal band on its walkway, connected to the apron. ------------
    tx, t_top = 480, 140
    seq = ["corner_glass_l", "terminal_glass_low", "terminal_doors",
           "terminal_glass_low", "corner_glass_r"]
    t_end, glass_y, t_bottom = terminal_band(canvas, tx, t_top, seq)
    walkway(canvas, tx - 8, t_end + 8, t_bottom, apron[1])
    canvas.alpha_composite(piece("sign_terminal").crop((0, 0, 44, 32)),
                           (tx + 18, t_bottom - 26))

    # --- Painted aircraft stands + service lane. ---------------------------
    lane_y = 540
    stand_markings(canvas, 620, 420, 1, lane_y)
    stand_markings(canvas, 860, 420, 2, lane_y)
    service_lane(canvas, apron[0] + 8, apron[2] - 8, 576, stop_xs=[548, 988])
    props(canvas, [
        ("sign_gate", 700, 300), ("sign_gate_green", 790, 300),
        ("light_pole", 452, 300), ("light_pole", 1030, 300),
        ("floodlights", 452, 596), ("grate", 990, 320),
        ("manhole", 470, 520), ("stain_oil", 640, 452),
        # Small GSE at tug scale, parked where the crews would leave it.
        ("tug_train", 700, 480), ("belt_loader", 920, 470),
        ("cart_luggage", 764, 330), ("truck_cargo", 990, 430),
        ("bags_cluster", 664, 336), ("bag_red", 930, 428),
        ("cone_small", 590, 452), ("cone_small", 900, 500),
    ])

    # --- West service cluster: hangar + fuel farm on a connected pad. ------
    pad(canvas, 150, 400, 400, 620)
    tile_rect(canvas, piece("concrete"), 400, 540, 440, 620)  # link road
    canvas.alpha_composite(piece("hangar_grey"), (170, 330))
    canvas.alpha_composite(piece("fuel_tank_round"), (300, 420))
    props(canvas, [
        ("tug_blue", 200, 470), ("jersey_striped", 204, 528),
        ("barrier_gate", 180, 560), ("stain_oil", 240, 540),
    ])

    # --- Reserved upgrade lots: empty pads the airline can build on. -------
    # The engine draws the built structure at each slot position; the paved
    # lot is baked so an unbuilt slot reads as a build site, not raw grass.
    pad(canvas, 268, 128, 484, 248)      # slot_terminal annex lot
    pad(canvas, 1068, 440, 1232, 560)    # slot_cargo lot

    # --- East cluster: tower + green office by the terminal. --------------
    pad(canvas, 1090, 220, 1290, 420)
    tile_rect(canvas, piece("concrete"), 1060, 320, 1090, 400)  # link
    canvas.alpha_composite(piece("tower_plain"), (1110, 130))
    canvas.alpha_composite(piece("office_green"), (1180, 250))
    props(canvas, [("truck_small", 1100, 350), ("light_pole", 1264, 240)])

    # --- Landside: access road, car park with cars, fence, pines. ---------
    road = piece("road_land_h")
    tile_rect(canvas, road, 0, 36, 480, 132)
    car_park(canvas, 480, 36, ["car_blue", "", "car_red", "", "car_green", ""])
    canvas.alpha_composite(piece("car_yellow", rotate=90), (330, 60))
    fence_run(canvas, 800, 1060, 96)
    fence_run(canvas, 60, 260, 148)   # stops short of the terminal-annex lot
    flora(canvas, [
        ("pine_small_a", 20, 180), ("pine_small_b", 70, 200),
        ("pine_small_a", 120, 170), ("bush_a", 170, 210),
        ("pine_small_b", 1300, 60), ("pine_small_a", 1250, 100),
        ("pine_small_b", 1310, 140), ("bush_c", 1260, 170),
        ("pine_small_a", 1080, 30), ("bush_b", 880, 110),
        ("pine_small_a", 40, 640), ("pine_small_b", 80, 690),
        ("bush_d", 20, 720), ("rock_a", 1240, 560),
        ("pine_small_b", 1290, 620), ("pine_small_a", 1330, 680),
        ("tuft_a", 860, 626), ("tuft_b", 1120, 624),
        ("tuft_a", 1250, 748), ("tuft_b", 240, 260),
        ("bush_b", 60, 480), ("tuft_a", 700, 626),
    ])

    # --- Geometry (scene pixels; the engine subtracts the centre offset). --
    cx, cy = W // 2, H // 2
    def pt(x, y): return [x - cx, y - cy]
    threshold_x = rx + 90
    stands = [("stand_1", 620, 420), ("stand_2", 860, 420)]
    geometry = {
        "scene": "airports/scenes/bzn.png",
        "ground_extent": [W, H],
        "camera_focus": pt(700, 350),
        "runway": {"start": pt(rx + 20, runway_c), "end": pt(runway_end_x - 20, runway_c),
                   "width": 96, "designations": ["36L", "18R"]},
        "stands": [
            {"id": "stand_1", "position": pt(620, 420), "heading": -90, "size": "small"},
            {"id": "stand_2", "position": pt(860, 420), "heading": -90, "size": "small"},
        ],
        "terminal_door": pt(700, 276),
        "upgrade_slots": [
            {"id": "slot_terminal", "visual_change": "terminal_level_2",
             "sprite": "terminal_2", "position": pt(376, 188)},
            {"id": "slot_hangar", "visual_change": "hangar_small",
             "sprite": "hangar_small", "position": pt(330, 560)},
            {"id": "slot_cargo", "visual_change": "cargo_shed",
             "sprite": "cargo_shed", "position": pt(1150, 500)},
        ],
        "ground": {
            "threshold": pt(threshold_x, runway_c), "rotate_at": pt(runway_end_x - 260, runway_c),
            "runway_end": pt(runway_end_x - 40, runway_c), "touchdown": pt(rx + 210, runway_c),
            "exit_at": pt(988, runway_c),
            "stands": stand_routes(stands, 540, 548, 988, runway_c, threshold_x, pt),
        },
    }
    return canvas, geometry


# ---------------------------------------------------------------------------
# BIL — plains regional: same vocabulary, terminal shifted west, brick band,
# a hint of town behind the fence.
# ---------------------------------------------------------------------------

def compose_bil() -> tuple[Image.Image, dict]:
    W, H = 1200, 780
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grass_base(canvas)

    runway_y = 660
    rx = 150
    runway_end_x = runway_strip(canvas, rx, runway_y, 10)
    runway_c = runway_y + 48

    apron = (240, 278, 760, 600)
    pad(canvas, *apron)
    taxi_x = 640
    vtaxiway(canvas, taxi_x, 600, runway_y + 8)

    # Terminal to the west; its brick paver band survives from the old BIL.
    tx, t_top = 260, 124
    seq = ["corner_glass_l", "terminal_glass_low", "terminal_doors_b"]
    t_end, glass_y, t_bottom = terminal_band(canvas, tx, t_top, seq)
    walkway(canvas, tx - 8, apron[2], t_bottom, apron[1])
    canvas.alpha_composite(piece("sign_terminal").crop((0, 0, 44, 32)),
                           (tx + 16, t_bottom - 26))

    lane_y = 520
    stand_markings(canvas, 430, 410, 1, lane_y)
    stand_markings(canvas, 610, 410, 2, lane_y)
    service_lane(canvas, apron[0] + 8, apron[2] - 8, 556, stop_xs=[688])
    props(canvas, [
        ("sign_gate", 500, 292), ("light_pole", 252, 290),
        ("light_pole", 730, 290), ("grate", 700, 300),
        ("manhole", 270, 480), ("stain_oil", 450, 440),
        ("tug_blue", 520, 470), ("cart_luggage", 350, 320),
        ("bag_blue", 400, 326), ("bag_khaki", 660, 470),
        ("belt_loader", 680, 420), ("cone_small", 300, 540),
    ])

    # East service cluster near the runway end: office + fuel on a pad.
    pad(canvas, 860, 470, 1060, 620)
    tile_rect(canvas, piece("concrete"), 760, 540, 860, 600)  # link road
    canvas.alpha_composite(piece("office_green"), (880, 380))
    canvas.alpha_composite(piece("fuel_tank_round"), (970, 470))
    props(canvas, [("truck_cargo", 890, 500), ("jersey_grey", 1010, 560),
                   ("barrier_gate", 870, 560)])

    # Landside: road from the west feeding the car park, a hint of town east.
    road = piece("road_land_h")
    tile_rect(canvas, road, 0, 24, 700, 120)
    car_park(canvas, 700, 24, ["car_grey", "", "car_purple", "", "", "car_red"])
    fence_run(canvas, 700, 1010, 120)
    fence_run(canvas, 20, 240, 140)
    flora(canvas, [
        ("house_a", 1020, 30), ("house_c", 1080, 90), ("house_b", 1130, 20),
        ("bush_c", 1000, 100), ("tuft_a", 1060, 150), ("plot_c", 1140, 130),
        ("bush_d", 60, 160), ("tuft_b", 140, 180), ("rock_a", 60, 596),
        ("tuft_a", 90, 620), ("tuft_b", 320, 596), ("bush_c", 40, 700),
        ("tuft_a", 1000, 620), ("rock_b", 1100, 680), ("tuft_b", 1160, 620),
        ("tuft_a", 840, 300), ("bush_d", 804, 292), ("tuft_b", 900, 340),
    ])

    # Reserved upgrade lots (see compose_bzn): annex east of the terminal,
    # hangar lot on the quiet west side.
    pad(canvas, 736, 146, 952, 266)
    pad(canvas, 32, 420, 248, 540)

    cx, cy = W // 2, H // 2
    def pt(x, y): return [x - cx, y - cy]
    threshold_x = rx + 90
    stands = [("stand_1", 430, 410), ("stand_2", 610, 410)]
    geometry = {
        "scene": "airports/scenes/bil.png",
        "ground_extent": [W, H],
        "camera_focus": pt(480, 330),
        "runway": {"start": pt(rx + 20, runway_c), "end": pt(runway_end_x - 20, runway_c),
                   "width": 96, "designations": ["36L", "18R"]},
        "stands": [
            {"id": "stand_1", "position": pt(430, 410), "heading": -90, "size": "small"},
            {"id": "stand_2", "position": pt(610, 410), "heading": -90, "size": "small"},
        ],
        "terminal_door": pt(470, 260),
        "upgrade_slots": [
            {"id": "slot_hangar", "visual_change": "hangar_small",
             "sprite": "hangar_small", "position": pt(140, 480)},
            {"id": "slot_terminal", "visual_change": "terminal_level_2",
             "sprite": "terminal_2", "position": pt(844, 206)},
        ],
        "ground": {
            "threshold": pt(threshold_x, runway_c), "rotate_at": pt(runway_end_x - 260, runway_c),
            "runway_end": pt(runway_end_x - 40, runway_c), "touchdown": pt(rx + 210, runway_c),
            "exit_at": pt(taxi_x + 48, runway_c),
            "stands": stand_routes(stands, 520, 688, taxi_x + 48, runway_c,
                                   threshold_x, pt),
        },
    }
    return canvas, geometry


# ---------------------------------------------------------------------------
# DEN — the hub: two parallel runways, a wide multi-gate terminal, five stands
# including one large, a cargo corner and a busier apron.
# ---------------------------------------------------------------------------

def compose_den() -> tuple[Image.Image, dict]:
    W, H = 1900, 1060
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    grass_base(canvas)

    # Main runway close to the apron; the second parallel further south.
    runway_y = 760
    rx = 120
    runway_end_x = runway_strip(canvas, rx, runway_y, 25)
    runway_c = runway_y + 48
    runway_strip(canvas, 350, 940, 25)          # visual parallel 16/34

    apron = (420, 354, 1560, 690)
    pad(canvas, *apron)
    for taxi_x in (500, 1360):
        vtaxiway(canvas, taxi_x, 690, runway_y + 8)

    tx, t_top = 450, 200
    seq = ["corner_glass_l", "terminal_glass_low", "terminal_doors",
           "terminal_glass_low", "terminal_doors_b", "terminal_glass_low",
           "corner_glass_r"]
    t_end, glass_y, t_bottom = terminal_band(canvas, tx, t_top, seq)
    walkway(canvas, tx - 8, t_end + 8, t_bottom, apron[1])
    canvas.alpha_composite(piece("sign_terminal").crop((0, 0, 44, 32)),
                           (tx + 18, t_bottom - 26))
    canvas.alpha_composite(piece("poster_fly").crop((0, 6, 96, 90)),
                           (tx + 96, glass_y - 26))
    canvas.alpha_composite(piece("poster_duty").crop((0, 6, 96, 90)),
                           (t_end - 200, glass_y - 26))

    # Five stands: four small, one large for the big jets.
    lane_y = 600
    for i, (sx, size) in enumerate([(620, "small"), (780, "small"),
                                    (940, "medium"), (1100, "medium")]):
        stand_markings(canvas, sx, 480, i + 1, lane_y, size)
    stand_markings(canvas, 1310, 480, 5, lane_y, "large")
    service_lane(canvas, apron[0] + 8, apron[2] - 8, 646, stop_xs=[548, 1408])
    # Library STOP/chevron band marks the throat onto the west taxiway.
    canvas.alpha_composite(piece("hold_stop").crop((0, 0, 96, 96)),
                           (500, 594))
    props(canvas, [
        ("sign_gate", 700, 360), ("sign_gate_green", 860, 360),
        ("sign_gate", 1020, 360), ("sign_gate_green", 1240, 360),
        ("light_pole", 432, 360), ("light_pole", 1530, 360),
        ("floodlights", 398, 700), ("floodlights", 1500, 660),
        ("grate", 1450, 380), ("manhole", 450, 560),
        ("stain_oil", 640, 512), ("stain_oil", 960, 512), ("stain_oil", 1290, 530),
        ("tug_train", 690, 540), ("tug_train", 1010, 540),
        ("truck_cargo", 1480, 430), ("truck_small", 830, 620),
        ("tug_blue", 560, 500), ("belt_loader", 1180, 540),
        ("cart_luggage", 745, 396), ("cart_luggage", 1065, 396),
        ("bags_cluster", 688, 400), ("bag_green", 905, 404),
        ("bag_red", 1152, 402), ("bag_blue", 1380, 420),
        ("bag_purple", 1420, 440), ("cone_small", 590, 512),
        ("cone_small", 1230, 570), ("jersey_grey", 1520, 620),
    ])

    # West fuel farm.
    pad(canvas, 170, 480, 380, 660)
    tile_rect(canvas, piece("concrete"), 380, 560, 420, 640)
    canvas.alpha_composite(piece("fuel_tank_round"), (190, 390))
    canvas.alpha_composite(piece("fuel_tank_round"), (280, 420))
    props(canvas, [("barrier_gate", 200, 590), ("jersey_striped", 300, 600),
                   ("truck_cargo", 250, 520)])

    # East: tower by the terminal, then the cargo corner.
    pad(canvas, 1600, 260, 1880, 660)
    tile_rect(canvas, piece("concrete"), 1560, 560, 1600, 640)
    canvas.alpha_composite(piece("tower_plain"), (1600, 200))
    canvas.alpha_composite(piece("hangar_grey"), (1720, 210))
    canvas.alpha_composite(piece("containers_stack"), (1620, 330))
    canvas.alpha_composite(piece("container_teal"), (1780, 370))
    props(canvas, [
        ("pallet_zone", 1640, 460), ("crate_wood", 1660, 480),
        ("crate_blue", 1700, 500), ("bag_khaki", 1670, 550),
        ("cart_luggage", 1760, 480), ("tug_train", 1640, 580),
        ("truck_small", 1824, 270), ("stain_oil", 1730, 620),
    ])

    # Landside: road, twin car parks, long fence, restrained greenery.
    road = piece("road_land_h")
    tile_rect(canvas, road, 0, 40, 450, 136)
    tile_rect(canvas, road, 1430, 40, W, 136)
    tile_rect(canvas, piece("road_land_v"), 1430, 40, 1526, 200)
    car_park(canvas, 450, 40,
             ["car_blue", "car_yellow", "", "car_black", "car_red", ""])
    car_park(canvas, 738, 40,
             ["", "car_green", "car_grey", "", "car_purple", "car_silver"])
    canvas.alpha_composite(piece("car_silver", rotate=90), (200, 64))
    fence_run(canvas, 1060, 1430, 140)
    fence_run(canvas, 40, 440, 152)
    fence_run(canvas, 1540, 1880, 150)
    flora(canvas, [
        ("bush_a", 60, 180), ("tuft_a", 140, 200), ("bush_c", 1090, 170),
        ("tuft_b", 1200, 190), ("bush_b", 1330, 180), ("tuft_a", 260, 210),
        ("tuft_a", 200, 700), ("tuft_b", 320, 880), ("rock_a", 1600, 880),
        ("tuft_a", 1700, 720), ("tuft_b", 1780, 900), ("rock_b", 240, 900),
        ("tuft_a", 1560, 130), ("bush_d", 1830, 200),
        ("tuft_b", 900, 700), ("tuft_a", 1150, 890),
    ])

    cx, cy = W // 2, H // 2
    def pt(x, y): return [x - cx, y - cy]
    threshold_x = rx + 90
    stands = [("stand_1", 620, 480), ("stand_2", 780, 480),
              ("stand_3", 940, 480), ("stand_4", 1100, 480),
              ("stand_5", 1310, 480)]
    geometry = {
        "scene": "airports/scenes/den.png",
        "ground_extent": [W, H],
        "camera_focus": pt(900, 450),
        "runway": {"start": pt(rx + 20, runway_c), "end": pt(runway_end_x - 20, runway_c),
                   "width": 96, "designations": ["36L", "18R"]},
        "stands": [
            {"id": "stand_1", "position": pt(620, 480), "heading": -90, "size": "small"},
            {"id": "stand_2", "position": pt(780, 480), "heading": -90, "size": "small"},
            {"id": "stand_3", "position": pt(940, 480), "heading": -90, "size": "medium"},
            {"id": "stand_4", "position": pt(1100, 480), "heading": -90, "size": "medium"},
            {"id": "stand_5", "position": pt(1310, 480), "heading": -90, "size": "large"},
        ],
        "terminal_door": pt(960, 340),
        "upgrade_slots": [
            {"id": "slot_hangar", "visual_change": "hangar_small",
             "sprite": "hangar_small", "position": pt(1830, 610)},
        ],
        "ground": {
            "threshold": pt(threshold_x, runway_c), "rotate_at": pt(runway_end_x - 260, runway_c),
            "runway_end": pt(runway_end_x - 40, runway_c), "touchdown": pt(rx + 210, runway_c),
            "exit_at": pt(1408, runway_c),
            "stands": stand_routes(stands, 600, 548, 1408, runway_c,
                                   threshold_x, pt),
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
        if "upgrade_slots" in geometry:
            # Slots are authored in scene coordinates alongside everything
            # else; the stale procedural positions must not survive.
            layout["upgrade_slots"] = geometry["upgrade_slots"]
        # Procedural-only keys are gone on scene airports; leaving them invites
        # exactly the stale-fallback confusion that hid the scene last time.
        for stale in ("secondary_runways", "apron", "taxiways", "buildings",
                      "decor", "props", "fence", "service_points"):
            layout.pop(stale, None)
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, layout_id, compose in (
        ("bzn", "layout_bzn", compose_bzn),
        ("bil", "layout_bil", compose_bil),
        ("den", "layout_den", compose_den),
    ):
        scene, geometry = compose()
        scene.save(OUT / f"{name}.png")
        (OUT / f"{name}.png.import").unlink(missing_ok=True)
        merge_layout(layout_id, geometry)
        print(f"{name} scene:", scene.size)
