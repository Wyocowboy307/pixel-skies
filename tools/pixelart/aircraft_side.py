"""Charming side-profile aircraft.

A deliberate break from the earlier side view, which was long, level and
technical — an aircraft diagram rather than a plane you would want to own.

The rules here are game-personality first:

* **Compact and chunky.** Body ratio near 2:1, not the 2.6:1 of a real light
  aircraft. Short, tall, round.
* **Windows are furniture.** They are sized to seat a visible passenger, because
  the detail screen draws little people into them. A window too small to hold a
  passenger is just a dark rectangle.
* **Exaggerate the parts with personality** — nose, fin, prop, wheels — and
  shrink everything else.

The builder emits anchor points alongside the sprite so the game knows exactly
where to draw passengers, cargo and the propeller. Those positions are art, not
gameplay, so they belong with the art.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from .canvas import Canvas
from .palette import LIVERIES


@dataclass(frozen=True)
class CharmSide:
    """Hand-tuned proportions for one charming side profile."""

    canvas: tuple[int, int]
    body_length: int
    body_height: int
    nose_start: float           # fraction of length where the round nose begins
    tail_end: float             # fraction of length where the tail cone begins
    tail_keep: float            # height retained at the very tail
    fin_height: int
    fin_root: int
    gear_height: int
    wheel_radius: int
    prop_radius: int
    seat_slot: int              # window size — must fit a passenger sprite
    seats: int
    seat_start: int             # x of the first window, from the tail
    seat_step: int
    cargo_slot: int
    cargo_slots: int
    cargo_start: int
    cargo_step: int
    seat_row_y: int             # from body top
    cargo_row_y: int
    livery: str = "house"


TRAILHOPPER = CharmSide(
    # Longer than the first pass: the cutaway band needs runway. The band must
    # end before the nose begins or it eats the windscreen, and it may overlap
    # the tail cone only slightly.
    canvas=(176, 96),
    body_length=132, body_height=44,
    nose_start=0.82, tail_end=0.20, tail_keep=0.36,
    fin_height=27, fin_root=25,
    gear_height=12, wheel_radius=8, prop_radius=16,
    # Six seat anchors, not four: the cabin band is sized for the upgraded
    # aircraft, so buying Cabin Plus visibly adds seats to the same airframe.
    seat_slot=10, seats=6, seat_start=27, seat_step=12,
    cargo_slot=10, cargo_slots=4, cargo_start=33, cargo_step=12,
    seat_row_y=5, cargo_row_y=22,
)


def _livery(name: str) -> dict[str, str]:
    return LIVERIES.get(name, LIVERIES["house"])


def _shade(offset: int, half: int, light: str, base: str, dark: str) -> str:
    if half <= 1:
        return base
    edge = max(1, half // 3)
    if offset <= -half + edge:
        return light
    if offset >= half - edge:
        return dark
    return base


def _profile(style: CharmSide, body_top: int, belly: int) -> list[tuple[int, int]]:
    """Fuselage top and bottom per station, tail to nose.

    The nose is a circular bulge over the last sixth of the body: that roundness
    is most of what separates a toy from a diagram.
    """
    out: list[tuple[int, int]] = []
    height = float(belly - body_top)
    for i in range(style.body_length):
        t = i / float(style.body_length - 1)
        top = float(body_top)
        bottom = float(belly)
        if t >= style.nose_start:
            run = (t - style.nose_start) / max(1e-6, 1.0 - style.nose_start)
            drop = (1.0 - math.sqrt(max(0.0, 1.0 - run * run))) * height * 0.5
            top += drop * 1.10
            bottom -= drop * 0.70
        elif t <= style.tail_end:
            run = 1.0 - t / max(1e-6, style.tail_end)
            keep = 1.0 - (1.0 - style.tail_keep) * run
            centre = (body_top + belly) * 0.5 - height * 0.20 * run
            top = centre - height * keep * 0.5
            bottom = centre + height * keep * 0.5
        out.append((int(round(top)), int(round(bottom))))
    return out


def build(style: CharmSide = TRAILHOPPER) -> tuple[Canvas, dict]:
    """Returns the sprite and its anchor metadata."""
    width, height = style.canvas
    canvas = Canvas(width, height)
    livery = _livery(style.livery)

    baseline = height - 4
    belly = baseline - style.gear_height
    body_top = belly - style.body_height
    nose = (width + style.body_length) // 2 - 1
    tail = nose - style.body_length + 1
    profile = _profile(style, body_top, belly)

    def station(x: int) -> tuple[int, int]:
        return profile[max(0, min(len(profile) - 1, x - tail))]

    seats = [(tail + style.seat_start + i * style.seat_step, body_top + style.seat_row_y)
             for i in range(style.seats)]
    cargo = [(tail + style.cargo_start + i * style.cargo_step, body_top + style.cargo_row_y)
             for i in range(style.cargo_slots)]

    _fin(canvas, style, livery, tail, body_top)
    _wing(canvas, style, livery, nose, body_top)
    _body(canvas, style, livery, tail, nose, station)
    _cabin(canvas, style, livery, seats, cargo, station)
    _nose(canvas, style, livery, nose, station)
    _gear(canvas, style, nose, tail, baseline, station)
    canvas.outline()

    anchors = {
        "canvas": [width, height],
        "baseline": baseline,
        "seat_slot": style.seat_slot,
        "cargo_slot": style.cargo_slot,
        # Top-left corners of each slot, so the game can blit into them directly.
        "seats": [[x, y] for x, y in seats],
        "cargo": [[x, y] for x, y in cargo],
        "prop": [nose + 4, (station(nose)[0] + station(nose)[1]) // 2],
        "nose": [nose, (station(nose)[0] + station(nose)[1]) // 2],
        "tail": [tail, body_top],
    }
    return canvas, anchors


def _body(canvas: Canvas, style: CharmSide, livery: dict[str, str],
          tail: int, nose: int, station) -> None:
    for x in range(tail, nose + 1):
        top, bottom = station(x)
        for y in range(top, bottom + 1):
            offset = y - (top + bottom) // 2
            half = max(1, (bottom - top) // 2)
            canvas.plot(x, y, _shade(offset, half, livery["light"], livery["base"], livery["dark"]))
    # Belly stripe in the airline colour, following the hull.
    for x in range(tail + 3, nose - 3):
        top, bottom = station(x)
        canvas.plot(x, bottom - 2, livery["trim"])
        canvas.plot(x, bottom - 3, livery["trim"])


def _cabin(canvas: Canvas, style: CharmSide, livery: dict[str, str],
           seats: list[tuple[int, int]], cargo: list[tuple[int, int]], station) -> None:
    """The open cutaway interior — the defining feature of the plane screen.

    Instead of windows, the fuselage side is cut away to show a bright cabin
    band and an open hold. The band itself is empty: the game draws seats,
    passengers and crates onto the anchors, so what the player sees inside the
    aircraft is always the actual manifest (and upgrades add real seats).
    """
    slot = style.seat_slot
    if seats:
        x0 = seats[0][0] - 2
        x1 = seats[-1][0] + slot + 2
        y0 = seats[0][1] - 2
        height = slot + 5
        canvas.rect(x0, y0, x1 - x0, height, "white")
        canvas.hline(x0, x1 - 1, y0 + height - 2, "ice")        # cabin floor
        canvas.hline(x0, x1 - 1, y0 + height - 1, "ice")
        canvas.hline(x0, x1 - 1, y0, "ice_light")               # ceiling shade
        canvas.rect_outline(x0 - 1, y0 - 1, x1 - x0 + 2, height + 2, livery["dark"])
        canvas.rect_outline(x0, y0, x1 - x0, height, "outline")

    bay = style.cargo_slot
    if cargo:
        left = cargo[0][0] - 2
        right = cargo[-1][0] + bay + 2
        top = cargo[0][1] - 2
        height = bay + 4
        canvas.rect(left, top, right - left, height, "ice_light")
        canvas.hline(left, right - 1, top + height - 2, "ice")   # hold floor
        canvas.hline(left, right - 1, top + height - 1, "ice")
        canvas.rect_outline(left - 1, top - 1, right - left + 2, height + 2, livery["dark"])
        canvas.rect_outline(left, top, right - left, height, "outline")


def _wing(canvas: Canvas, style: CharmSide, livery: dict[str, str],
          nose: int, body_top: int) -> None:
    """High wing sitting on the roof, with a stubby strut."""
    chord = int(style.body_length * 0.30)
    leading = nose - int(style.body_length * 0.34)
    thickness = 6
    y = body_top - thickness + 2
    for x in range(leading - chord, leading + 1):
        run = (leading - x) / max(1, chord)
        rows = thickness if run < 0.62 else max(3, thickness - 2)
        for dy in range(rows):
            colour = livery["light"] if dy == 0 else (
                livery["dark"] if dy == rows - 1 else livery["base"])
            canvas.plot(x, y + dy, colour)


def _fin(canvas: Canvas, style: CharmSide, livery: dict[str, str],
         tail: int, body_top: int) -> None:
    """Oversized swept fin — the most characterful part of the silhouette."""
    root = style.fin_root
    top_y = body_top - style.fin_height
    for x in range(tail, tail + root + 1):
        run = (tail + root - x) / float(max(1, root))
        rise = min(1.0, run / 0.66)
        y_top = int(round(body_top - style.fin_height * rise))
        if run > 0.88:
            y_top += 2
        for y in range(y_top, body_top + 4):
            canvas.plot(x, y, livery["light"] if y <= y_top + 1 else livery["base"])
    for x in range(tail + 2, tail + root - 2):
        run = (tail + root - x) / float(max(1, root))
        y = int(round(body_top - style.fin_height * min(1.0, run / 0.66) * 0.55))
        canvas.plot(x, y, livery["trim"])
        canvas.plot(x, y + 1, livery["trim"])
    # Tailplane, chunky and short.
    for x in range(tail + 1, tail + root - 4):
        canvas.plot(x, body_top + 2, livery["light"])
        canvas.plot(x, body_top + 3, livery["base"])
        canvas.plot(x, body_top + 4, livery["dark"])


def _nose(canvas: Canvas, style: CharmSide, livery: dict[str, str],
          nose: int, station) -> None:
    """Cowl, wrapped windscreen and a big propeller."""
    length = style.body_length
    # Windscreen wrapping the top of the nose.
    back = nose - int(length * 0.17)
    front = nose - int(length * 0.05)
    for x in range(back, front + 1):
        run = (x - back) / float(max(1, front - back))
        top, bottom = station(x)
        rows = max(3, int(round(style.body_height * 0.34 * (1.0 - run * 0.55))))
        rows = min(rows, max(2, bottom - top - 3))
        for dy in range(rows):
            canvas.plot(x, top + 2 + dy, "glass_light" if dy == 0 else "glass")
    canvas.vline(back - 1, station(back)[0] + 2, station(back)[0] + 10, "metal_dark")
    # The pilot, visible through the glass: two pixels of person that make the
    # aircraft read as crewed rather than empty.
    var_top = station(back + 2)[0]
    canvas.rect(back + 2, var_top + 4, 3, 3, "sand_light")
    canvas.hline(back + 2, back + 4, var_top + 4, "soil")
    canvas.rect(back + 2, var_top + 7, 3, 2, "btn_green")

    # Cowl.
    for x in range(nose - 5, nose + 1):
        top, bottom = station(x)
        for y in range(top, bottom + 1):
            offset = y - (top + bottom) // 2
            canvas.plot(x, y, _shade(offset, max(1, (bottom - top) // 2),
                                     "metal_light", "metal", "metal_dark"))
    top, bottom = station(nose)
    _prop(canvas, nose + 4, (top + bottom) // 2, style.prop_radius)


def _prop(canvas: Canvas, x: int, centre_y: int, radius: int) -> None:
    blade = max(3, radius // 4)
    hub = max(4, radius // 3)
    for dy in range(-radius, radius + 1):
        t = abs(dy) / float(max(1, radius))
        width = blade if t < 0.6 else max(1, blade - 1)
        for dx in range(width):
            canvas.plot(x - dx, centre_y + dy, "metal_light" if dy < 0 else "metal_dark")
    canvas.ellipse(x - blade // 2, centre_y, hub * 0.9, hub, "metal")
    canvas.ellipse(x - blade // 2 - 1, centre_y - hub // 3, hub * 0.45, hub * 0.45, "metal_light")


def _gear(canvas: Canvas, style: CharmSide, nose: int, tail: int,
          baseline: int, station) -> None:
    """Short fat legs and big fat wheels — toy running gear."""
    def leg(x: int, radius: float, ground: int) -> None:
        top = station(x)[1]
        centre_y = ground - radius
        canvas.rect(x - 2, top, 5, max(1, int(centre_y - top)), "metal_dark")
        canvas.disc(x, centre_y, radius + 0.4, "asphalt_dark")
        canvas.disc(x, centre_y, max(1.5, radius - 2.4), "metal_dark")
        canvas.plot(x, int(centre_y), "metal_light")

    leg(nose - int(style.body_length * 0.44), style.wheel_radius, baseline)
    leg(tail + int(style.body_length * 0.07), style.wheel_radius * 0.5, baseline - 4)
