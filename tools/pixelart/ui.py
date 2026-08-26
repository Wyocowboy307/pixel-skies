"""Pixel UI: 9-slice frames, buttons and icons.

Panels are chunky bevelled frames rather than rounded translucent cards, so the
management layer belongs to the same world as the airfield under it.
"""

from __future__ import annotations

from .canvas import Canvas


def nine_slice(size: int, border: int, fill: str, edge: str, highlight: str,
               shade: str) -> Canvas:
    """A bevelled frame with a 1 px outer outline.

    Light from the upper left: the top and left inner bevel is `highlight`, the
    bottom and right is `shade`.
    """
    canvas = Canvas(size, size)
    canvas.rect(0, 0, size, size, fill)
    canvas.rect_outline(0, 0, size, size, "outline")
    canvas.rect_outline(1, 1, size - 2, size - 2, edge)
    # Inner bevel.
    canvas.hline(2, size - 3, 2, highlight)
    canvas.vline(2, 2, size - 3, highlight)
    canvas.hline(2, size - 3, size - 3, shade)
    canvas.vline(size - 3, 2, size - 3, shade)
    if border >= 4:
        canvas.plot(2, 2, highlight)
        canvas.plot(size - 3, size - 3, shade)
    return canvas


def panel() -> Canvas:
    """Main HUD panel. 4 px border, so the 9-slice centre is 1 px."""
    return nine_slice(9, 4, "ui_bg", "ui_border", "ui_border_light", "outline")


def panel_raised() -> Canvas:
    return nine_slice(9, 4, "ui_bg_light", "ui_border", "ui_border_light", "outline")


def button_normal() -> Canvas:
    return nine_slice(7, 3, "ui_bg_light", "ui_border", "ui_border_light", "outline")


def button_hover() -> Canvas:
    return nine_slice(7, 3, "ui_border", "ui_border_light", "white", "outline")


def button_pressed() -> Canvas:
    """Pressed inverts the bevel, which is the oldest and clearest press cue."""
    return nine_slice(7, 3, "ui_bg", "ui_border", "outline", "ui_border_light")


def button_disabled() -> Canvas:
    return nine_slice(7, 3, "ui_bg", "ui_bg_light", "ui_bg_light", "outline")


def row_normal() -> Canvas:
    canvas = Canvas(5, 5)
    canvas.rect(0, 0, 5, 5, "ui_bg_light")
    canvas.hline(0, 4, 0, "ui_border")
    return canvas


def row_hover() -> Canvas:
    canvas = Canvas(5, 5)
    canvas.rect(0, 0, 5, 5, "ui_border")
    canvas.hline(0, 4, 0, "ui_border_light")
    return canvas


FRAMES: dict[str, callable] = {
    "panel": panel,
    "panel_raised": panel_raised,
    "button_normal": button_normal,
    "button_hover": button_hover,
    "button_pressed": button_pressed,
    "button_disabled": button_disabled,
    "row_normal": row_normal,
    "row_hover": row_hover,
}


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
    """Larger, with a hole punched through, so a hub reads differently from a
    regional field without needing a label."""
    canvas = Canvas(9, 9)
    for y in range(9):
        spread = 3 - abs(y - 4) + 1
        if spread < 0:
            continue
        canvas.hline(4 - spread, 4 + spread, y, "accent_orange")
    canvas.plot(4, 3, "accent_orange_light")
    canvas.plot(3, 4, "accent_orange_light")
    canvas.plot(4, 4, "ui_bg")
    canvas.outline()
    return canvas


def marker_selected() -> Canvas:
    """A 13x13 open ring drawn around whichever marker is selected."""
    canvas = Canvas(13, 13)
    canvas.ring(6, 6, 5, "white")
    # Break the ring at the diagonals so it reads as a reticle, not a blob.
    for x, y in ((2, 2), (10, 2), (2, 10), (10, 10), (3, 3), (9, 3), (3, 9), (9, 9)):
        canvas.plot(x, y, None)
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
