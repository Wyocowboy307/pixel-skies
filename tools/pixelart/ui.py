"""Pixel UI: 9-slice frames, buttons and icons.

Panels are chunky bevelled frames rather than rounded translucent cards, so the
management layer belongs to the same world as the airfield under it.
"""

from __future__ import annotations

from .canvas import Canvas

## The live frame set is the bright "chunky" family at the bottom of this file.
## The old dark admin set and the intermediate warm set were retired: their
## PNGs were referenced by no script and only confused art passes.
FRAMES: dict[str, callable] = {}


# ---------------------------------------------------------------------------
# Icons — 10x10, one idea each, readable at 1:1
# ---------------------------------------------------------------------------

def icon_passenger() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.disc(4.5, 2.5, 2.0, "accent_teal")
    canvas.rect(2, 5, 6, 5, "accent_teal")
    canvas.hline(2, 7, 5, "white")
    canvas.outline()
    return canvas


def icon_cargo() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.rect(1, 2, 8, 7, "accent_yellow")
    canvas.hline(1, 8, 2, "sand_light")
    canvas.hline(1, 8, 5, "soil")
    canvas.vline(4, 2, 8, "soil")
    canvas.outline()
    return canvas


def icon_contract() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.rect(2, 1, 6, 8, "white")
    canvas.hline(3, 6, 3, "accent_red")
    canvas.hline(3, 6, 5, "text_dim")
    canvas.hline(3, 5, 7, "text_dim")
    canvas.outline()
    return canvas


def icon_money() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.disc(4.5, 4.5, 4.0, "accent_orange")
    canvas.disc(4.5, 4.5, 2.6, "accent_orange_light")
    canvas.vline(4, 2, 7, "accent_orange")
    canvas.outline()
    return canvas


def icon_clock() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.disc(4.5, 4.5, 4.0, "ui_border_light")
    canvas.disc(4.5, 4.5, 3.0, "ui_bg")
    canvas.vline(4, 2, 4, "white")
    canvas.hline(4, 6, 4, "white")
    canvas.outline()
    return canvas


def icon_plane() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.hline(1, 8, 4, "livery_light")
    canvas.vline(5, 1, 8, "livery")
    canvas.hline(2, 8, 5, "livery_dark")
    canvas.vline(2, 3, 6, "livery")
    canvas.outline()
    return canvas


def icon_warning() -> Canvas:
    canvas = Canvas(10, 10)
    canvas.polygon([(4, 0), (9, 9), (0, 9)], "accent_red")
    canvas.vline(4, 3, 6, "white")
    canvas.plot(4, 8, "white")
    canvas.outline()
    return canvas


def icon_fuel() -> Canvas:
    """A jerrycan — reads as fuel at 10px where a droplet does not."""
    canvas = Canvas(10, 10)
    canvas.rect(1, 2, 7, 7, "accent_teal")
    canvas.hline(1, 7, 2, "ice")
    canvas.vline(1, 2, 8, "ice")
    canvas.rect(3, 0, 3, 2, "metal_dark")
    canvas.vline(8, 3, 6, "metal")
    canvas.outline()
    return canvas


def icon_range() -> Canvas:
    """A double-headed arrow between two posts. At 10px the arrowheads have to
    be solid triangles; single-pixel barbs read as noise."""
    canvas = Canvas(10, 10)
    canvas.vline(0, 1, 8, "metal_light")
    canvas.vline(9, 1, 8, "metal_light")
    canvas.hline(2, 7, 5, "accent_teal")
    for i in range(3):
        canvas.vline(2 + i, 5 - (2 - i), 5 + (2 - i), "accent_teal")
        canvas.vline(7 - i, 5 - (2 - i), 5 + (2 - i), "accent_teal")
    canvas.outline()
    return canvas


def icon_route() -> Canvas:
    """Two airport dots joined by a dashed hop, which is exactly how a route
    is drawn on the world map — so the icon teaches the map."""
    canvas = Canvas(10, 10)
    canvas.rect(0, 7, 3, 3, "accent_orange")
    canvas.rect(7, 0, 3, 3, "accent_orange_light")
    for x, y in ((3, 6), (4, 5), (6, 3), (7, 2)):
        canvas.plot(x, y, "white")
    canvas.outline()
    return canvas


def icon_condition() -> Canvas:
    """A spanner: a thick diagonal shaft with an open jaw. A thin outline
    spanner is unreadable at this size, so it is drawn as solid mass."""
    canvas = Canvas(10, 10)
    for i in range(6):
        canvas.plot(2 + i, 7 - i, "metal")
        canvas.plot(3 + i, 7 - i, "metal_light")
    # Open jaw at the top right.
    canvas.rect(6, 0, 4, 4, "metal_light")
    canvas.plot(7, 0, "ui_bg")
    canvas.plot(7, 1, "ui_bg")
    canvas.plot(8, 0, "ui_bg")
    canvas.outline()
    return canvas


def icon_seat_slot() -> Canvas:
    """An empty seat in side profile: a chunky backrest, cushion and leg."""
    canvas = Canvas(10, 10)
    canvas.rect(1, 1, 3, 6, "ui_border_light")     # backrest
    canvas.rect(1, 6, 8, 2, "ui_border_light")     # cushion
    canvas.vline(8, 8, 9, "ui_border")             # leg
    canvas.vline(1, 8, 9, "ui_border")
    canvas.hline(1, 3, 1, "text_dim")
    canvas.outline()
    return canvas


def icon_cargo_slot() -> Canvas:
    """An empty pallet space."""
    canvas = Canvas(10, 10)
    canvas.rect_outline(1, 3, 8, 6, "ui_border_light")
    canvas.hline(2, 7, 8, "text_dim")
    canvas.outline()
    return canvas


def icon_upgrade() -> Canvas:
    """A building with an up arrow: an airport upgrade."""
    canvas = Canvas(10, 10)
    canvas.rect(0, 5, 6, 5, "roof_terminal")
    canvas.hline(0, 5, 5, "wall_light")
    canvas.rect(1, 7, 2, 2, "glass")
    for i in range(3):
        canvas.hline(6 - i, 8 + i, 4 - i, "accent_green")
    canvas.vline(7, 2, 4, "accent_green")
    canvas.outline()
    return canvas


def icon_speed() -> Canvas:
    """A gauge needle, for cruise speed."""
    canvas = Canvas(10, 10)
    canvas.ring(4, 5, 4, "ui_border_light")
    for x, y in ((4, 5), (5, 4), (6, 3), (7, 3)):
        canvas.plot(x, y, "accent_orange")
    canvas.plot(4, 5, "white")
    canvas.outline()
    return canvas


def icon_runway() -> Canvas:
    """A strip with a dashed centreline."""
    canvas = Canvas(10, 10)
    canvas.rect(1, 1, 8, 8, "asphalt")
    canvas.vline(1, 1, 8, "white")
    canvas.vline(8, 1, 8, "white")
    for y in (2, 5, 8):
        canvas.plot(4, y, "white")
        canvas.plot(5, y, "white")
    canvas.outline()
    return canvas


ICONS: dict[str, callable] = {
    "passenger": icon_passenger,
    "cargo": icon_cargo,
    "contract": icon_contract,
    "money": icon_money,
    "clock": icon_clock,
    "plane": icon_plane,
    "warning": icon_warning,
    "fuel": icon_fuel,
    "range": icon_range,
    "route": icon_route,
    "condition": icon_condition,
    "seat_slot": icon_seat_slot,
    "cargo_slot": icon_cargo_slot,
    "upgrade": icon_upgrade,
    "speed": icon_speed,
    "runway": icon_runway,
}


# ---------------------------------------------------------------------------
# World map markers
# ---------------------------------------------------------------------------

def marker_regional() -> Canvas:
    """A 7x7 diamond. Diamonds stay symmetric at odd pixel sizes, which keeps
    the marker centred exactly on the airport rather than half a pixel off."""
    canvas = Canvas(7, 7)
    for y in range(7):
        spread = 2 - abs(y - 3) + 1
        if spread < 0:
            continue
        canvas.hline(3 - spread, 3 + spread, y, "accent_yellow")
    canvas.plot(3, 2, "white")
    canvas.plot(2, 3, "white")
    canvas.outline()
    return canvas


def marker_major() -> Canvas:
    """A hub: an 11px orange diamond with a cream ring and a bright centre
    pip, so it outranks the plain 7px regional diamond at a glance. The ring
    is cream rather than light orange because at map scale only that contrast
    step actually reads as a ring."""
    canvas = Canvas(11, 11)
    for y in range(11):
        spread = 5 - abs(y - 5)
        if spread < 0:
            continue
        canvas.hline(5 - spread, 5 + spread, y, "accent_orange")
    # Ring at manhattan radius 3, pip in the middle, one NW glint (light from
    # the upper left, as everywhere).
    for y in range(11):
        for x in range(11):
            if abs(x - 5) + abs(y - 5) == 3:
                canvas.plot(x, y, "card")
    canvas.plot(5, 5, "white")
    canvas.plot(3, 3, "accent_orange_light")
    canvas.outline()
    return canvas


def marker_selected() -> Canvas:
    """A 15x15 pulse ring around whichever marker is selected: an open ring
    broken at the diagonals with a tick at each cardinal, so it reads as a
    reticle rather than a blob. Drawn white; the overlay modulates the pulse."""
    canvas = Canvas(15, 15)
    canvas.ring(7, 7, 6, "white")
    for y in range(15):
        for x in range(15):
            dx = abs(x - 7)
            dy = abs(y - 7)
            if dx >= 2 and dy >= 2 and abs(dx - dy) <= 1:
                canvas.plot(x, y, None)
    for x, y in ((7, 0), (7, 14), (0, 7), (14, 7)):
        canvas.plot(x, y, "white")
    return canvas


def marker_dot() -> Canvas:
    """The far-zoom marker: three pixels, per docs/WORLD_MAP_AND_ZOOM.md."""
    canvas = Canvas(3, 3)
    canvas.plot(1, 1, "white")
    canvas.plot(0, 1, "accent_yellow")
    canvas.plot(2, 1, "accent_yellow")
    canvas.plot(1, 0, "accent_yellow")
    canvas.plot(1, 2, "accent_yellow")
    return canvas


MARKERS: dict[str, callable] = {
    "marker_regional": marker_regional,
    "marker_major": marker_major,
    "marker_selected": marker_selected,
    "marker_dot": marker_dot,
}


# ---------------------------------------------------------------------------
# Bright game frames. Thicker than the warm set: a 1px outline, a 2px coloured
# edge and a 1px bevel, which is what makes a button read as a chunky game
# control rather than an admin widget.
# ---------------------------------------------------------------------------

def chunky(size: int, fill: str, edge: str, hi: str, lo: str) -> Canvas:
    canvas = Canvas(size, size)
    canvas.rect(0, 0, size, size, fill)
    canvas.rect_outline(0, 0, size, size, "outline")
    canvas.rect_outline(1, 1, size - 2, size - 2, edge)
    canvas.rect_outline(2, 2, size - 4, size - 4, edge)
    canvas.hline(3, size - 4, 3, hi)
    canvas.vline(3, 3, size - 4, hi)
    canvas.hline(3, size - 4, size - 4, lo)
    canvas.vline(size - 4, 3, size - 4, lo)
    return canvas


def _btn(fill: str, hi: str, lo: str) -> Canvas:
    return chunky(13, fill, "navy", hi, lo)


def hud_bar() -> Canvas:
    """The top HUD plate: a sky-blue slab with one crisp navy edge, a lit top
    lip and a shaded base. Thinner chrome than chunky() — a 1px navy edge
    instead of 2px — so at bar height most of the plate is still sky."""
    size = 13
    canvas = Canvas(size, size)
    canvas.rect(0, 0, size, size, "hud_blue")
    canvas.rect_outline(0, 0, size, size, "outline")
    canvas.rect_outline(1, 1, size - 2, size - 2, "navy")
    canvas.hline(2, size - 3, 2, "btn_blue_hi")
    canvas.vline(2, 3, size - 4, "btn_blue_hi")
    canvas.hline(2, size - 3, size - 3, "hud_blue_deep")
    canvas.vline(size - 3, 3, size - 4, "hud_blue_deep")
    return canvas


def hud_plate() -> Canvas:
    """A small plate set INTO the HUD bar — dark top shadow, light bottom lip,
    the inverse of a raised card — so the money and fleet readouts look like
    gauges built into the bar rather than text floating on a strip."""
    canvas = Canvas(5, 5)
    canvas.rect(0, 0, 5, 5, "hud_blue_deep")
    canvas.rect_outline(0, 0, 5, 5, "navy")
    canvas.hline(1, 3, 1, "navy_deep")
    canvas.hline(1, 3, 3, "hud_blue")
    return canvas


def tag_chip() -> Canvas:
    """A luggage-tag chip: warm yellow card, 1px outline, lit top lip and a
    punched hole. The hole sits in the top-left 6px corner of the 9-slice, and
    a corner is never stretched, so it appears exactly once per chip — the
    same tag language as the map's hand-drawn callsign chip."""
    size = 13
    canvas = Canvas(size, size)
    canvas.rect(0, 0, size, size, "accent_yellow")
    canvas.rect_outline(0, 0, size, size, "outline")
    canvas.hline(1, size - 2, 1, "card_hi")
    canvas.rect(2, 3, 2, 2, "outline")
    return canvas


FRAMES.update({
    "card": lambda: chunky(13, "card", "navy", "card_hi", "card_lo"),
    "card_raised": lambda: chunky(13, "card_hi", "navy", "white", "card_lo"),
    "hud_bar": hud_bar,
    "hud_plate": hud_plate,
    "tag_chip": tag_chip,
    "btn_plain_normal": lambda: _btn("card", "card_hi", "card_lo"),
    "btn_plain_hover": lambda: _btn("card_hi", "white", "card_lo"),
    "btn_plain_pressed": lambda: _btn("card_lo", "card_lo", "card_hi"),
    "btn_plain_disabled": lambda: chunky(13, "card_lo", "card_lo", "card_lo", "card_lo"),
    "btn_green_normal": lambda: _btn("btn_green", "btn_green_hi", "btn_green_lo"),
    "btn_green_hover": lambda: _btn("btn_green_hi", "white", "btn_green"),
    "btn_green_pressed": lambda: _btn("btn_green_lo", "btn_green_lo", "btn_green_hi"),
    "btn_green_disabled": lambda: chunky(13, "card_lo", "card_lo", "card_lo", "card_lo"),
    "btn_blue_normal": lambda: _btn("btn_blue", "btn_blue_hi", "btn_blue_lo"),
    "btn_blue_hover": lambda: _btn("btn_blue_hi", "white", "btn_blue"),
    "btn_blue_pressed": lambda: _btn("btn_blue_lo", "btn_blue_lo", "btn_blue_hi"),
    "btn_blue_disabled": lambda: chunky(13, "card_lo", "card_lo", "card_lo", "card_lo"),
    "btn_orange_normal": lambda: _btn("accent_orange", "accent_orange_light", "accent_red"),
    "btn_orange_hover": lambda: _btn("accent_orange_light", "white", "accent_orange"),
    "btn_orange_pressed": lambda: _btn("accent_red", "accent_red", "accent_orange_light"),
    "btn_orange_disabled": lambda: chunky(13, "card_lo", "card_lo", "card_lo", "card_lo"),
})
