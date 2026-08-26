"""Airport ground tiles, buildings and vehicles.

Surface tiles are 16x16 and seamless: every pattern is generated from
coordinates taken modulo the tile size, so a tile abuts itself on all four edges
without a visible join.
"""

from __future__ import annotations

import numpy as np

from .canvas import Canvas

TILE = 16


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _speckle(canvas: Canvas, colour: str, count: int, seed: int, size: int = TILE) -> None:
    """Scatter single pixels deterministically, wrapping at the tile edge."""
    rng = _rng(seed)
    for _ in range(count):
        x = int(rng.integers(0, size))
        y = int(rng.integers(0, size))
        canvas.plot(x, y, colour)


# ---------------------------------------------------------------------------
# Surface tiles
# ---------------------------------------------------------------------------

def grass(variant: int = 0, biome: str = "mountain") -> Canvas:
    base, alt, dark = {
        "mountain": ("grass", "grass_light", "grass_dark"),
        "plains": ("scrub", "grass_light", "grass"),
        "highplains": ("sand", "sand_light", "scrub"),
    }.get(biome, ("grass", "grass_light", "grass_dark"))
    canvas = Canvas(TILE, TILE)
    canvas.fill(base)
    _speckle(canvas, alt, 18, seed=1000 + variant)
    _speckle(canvas, dark, 12, seed=2000 + variant)
    return canvas


def asphalt(variant: int = 0) -> Canvas:
    canvas = Canvas(TILE, TILE)
    canvas.fill("asphalt")
    _speckle(canvas, "asphalt_light", 10, seed=3000 + variant)
    _speckle(canvas, "asphalt_dark", 14, seed=4000 + variant)
    return canvas


def taxiway_surface(variant: int = 0) -> Canvas:
    canvas = Canvas(TILE, TILE)
    canvas.fill("taxiway")
    _speckle(canvas, "concrete", 9, seed=5000 + variant)
    _speckle(canvas, "asphalt", 9, seed=6000 + variant)
    return canvas


def concrete_apron(variant: int = 0) -> Canvas:
    """Apron slabs — the expansion joints are what separate apron from runway."""
    canvas = Canvas(TILE, TILE)
    canvas.fill("concrete")
    _speckle(canvas, "concrete_light", 8, seed=7000 + variant)
    # Expansion joints, kept subtle: a hard dark joint on every tile edge makes
    # a tiled apron read as a grid rather than as a surface.
    canvas.hline(0, TILE - 1, 0, "taxiway")
    canvas.vline(0, 0, TILE - 1, "taxiway")
    return canvas


def runway_centreline() -> Canvas:
    """A dash occupying the middle of the tile, with gaps at both ends so a run
    of tiles produces evenly spaced stripes."""
    canvas = asphalt(variant=2)
    canvas.rect(3, TILE // 2 - 1, 10, 2, "white")
    return canvas


def runway_edge(top: bool = True) -> Canvas:
    canvas = asphalt(variant=3)
    y = 1 if top else TILE - 3
    canvas.hline(0, TILE - 1, y, "white")
    canvas.hline(0, TILE - 1, y + 1, "white")
    canvas.hline(0, TILE - 1, y + (2 if top else -1), "asphalt_light")
    return canvas


def runway_threshold() -> Canvas:
    """Piano keys: the clearest possible 'this end is a runway' cue."""
    canvas = asphalt(variant=4)
    for i in range(0, TILE, 4):
        canvas.rect(i, 2, 2, TILE - 4, "white")
    return canvas


def taxiway_centreline() -> Canvas:
    canvas = taxiway_surface(variant=2)
    canvas.hline(0, TILE - 1, TILE // 2 - 1, "accent_yellow")
    return canvas


def stand_marking() -> Canvas:
    canvas = concrete_apron(variant=2)
    canvas.hline(2, TILE - 3, TILE // 2, "accent_yellow")
    canvas.vline(TILE // 2, 3, TILE - 4, "accent_yellow")
    return canvas


SURFACE_TILES: dict[str, callable] = {
    "grass_mountain": lambda: grass(0, "mountain"),
    "grass_mountain_b": lambda: grass(1, "mountain"),
    "grass_plains": lambda: grass(0, "plains"),
    "grass_highplains": lambda: grass(0, "highplains"),
    "asphalt": lambda: asphalt(0),
    "asphalt_b": lambda: asphalt(1),
    "runway_centreline": runway_centreline,
    "runway_edge_top": lambda: runway_edge(True),
    "runway_edge_bottom": lambda: runway_edge(False),
    "runway_threshold": runway_threshold,
    "taxiway": lambda: taxiway_surface(0),
    "taxiway_centreline": taxiway_centreline,
    "apron": lambda: concrete_apron(0),
    "stand_marking": stand_marking,
}


# ---------------------------------------------------------------------------
# Buildings
# ---------------------------------------------------------------------------

def _roofed_block(width: int, height: int, roof: str, seed: int,
                  ribs: int = 0, rib_colour: str = "wall") -> Canvas:
    """A flat-lay building: roof plate, lit north-west edge, shadowed south face.

    Only a couple of pixels of side wall are shown — the 'tiny amount of
    readable side information' the art bible allows in a top-down view.
    """
    canvas = Canvas(width, height + 3)
    canvas.rect(0, 0, width, height, roof)
    # Upper-left light: bright top and left edges, dark bottom and right.
    canvas.hline(0, width - 1, 0, "wall_light")
    canvas.vline(0, 0, height - 1, "wall_light")
    canvas.hline(0, width - 1, height - 1, "wall")
    canvas.vline(width - 1, 0, height - 1, "wall")
    # Short south-facing wall so the building has visible mass.
    canvas.rect(0, height, width, 3, "wall")
    canvas.hline(0, width - 1, height, "wall_light")
    for i in range(ribs):
        x = round((i + 1) * width / (ribs + 1))
        canvas.vline(x, 1, height - 2, rib_colour)
    _speckle(canvas, "wall_light", max(2, width // 8), seed=seed, size=min(width, height))
    return canvas


def terminal(width: int = 96, height: int = 32, level: int = 1) -> Canvas:
    """Passenger terminal, seen flat-lay with a short south face.

    The glazed frontage, entrance canopy and rooftop plant are what separate a
    terminal from any other shed at a glance.
    """
    canvas = _roofed_block(width, height, "roof_terminal", seed=8100, ribs=0)
    # Roof ribs suggesting the structural bays.
    for x in range(8, width - 6, 12):
        canvas.vline(x, 2, height - 3, "wall")
        canvas.vline(x + 1, 2, height - 3, "wall_light")
    # Glazed frontage facing the apron.
    canvas.rect(3, height - 5, width - 6, 3, "glass")
    canvas.hline(3, width - 4, height - 5, "glass_light")
    for x in range(5, width - 4, 7):
        canvas.vline(x, height - 5, height - 3, "wall")
    # Entrance canopy, centred.
    canopy = max(12, width // 5)
    cx = (width - canopy) // 2
    canvas.rect(cx, height - 2, canopy, 4, "wall_light")
    canvas.hline(cx, cx + canopy - 1, height + 1, "wall")
    # Rooftop plant, more of it on a bigger terminal.
    for unit in range(1 + level):
        ux = 6 + unit * 16
        if ux + 10 > width - 6:
            break
        canvas.rect(ux, 4, 10, 6, "roof_hangar")
        canvas.hline(ux, ux + 9, 4, "metal_light")
        canvas.hline(ux, ux + 9, 9, "metal_dark")
    canvas.outline()
    return canvas


def hangar(width: int = 64, height: int = 34) -> Canvas:
    """Arched-roof hangar with a full-width door on the apron side."""
    canvas = _roofed_block(width, height, "roof_hangar", seed=8200, ribs=0)
    # Barrel roof read as three bands plus corrugation.
    canvas.rect(2, 2, width - 4, 5, "metal_light")
    canvas.rect(2, height - 12, width - 4, 5, "wall")
    for x in range(4, width - 3, 3):
        canvas.vline(x, 8, height - 13, "wall")
    # Sliding door with panel divisions.
    canvas.rect(4, height - 6, width - 8, 5, "asphalt_dark")
    for x in range(8, width - 6, 8):
        canvas.vline(x, height - 6, height - 2, "metal_dark")
    canvas.hline(4, width - 5, height - 6, "metal")
    canvas.outline()
    return canvas


def cargo_shed(width: int = 48, height: int = 28) -> Canvas:
    """Freight shed: roller doors and a loading apron edge."""
    canvas = _roofed_block(width, height, "roof_cargo", seed=8300, ribs=0)
    for x in range(6, width - 4, 10):
        canvas.vline(x, 2, height - 8, "wall")
    # Two roller doors with a dock strip in front.
    for door in range(2):
        dx = 5 + door * (width // 2 - 2)
        dw = width // 2 - 10
        if dx + dw > width - 4:
            break
        canvas.rect(dx, height - 7, dw, 6, "asphalt_dark")
        for y in range(height - 7, height - 2, 2):
            canvas.hline(dx, dx + dw - 1, y, "wall")
        canvas.hline(dx, dx + dw - 1, height - 7, "accent_yellow")
    canvas.outline()
    return canvas


def tower(width: int = 20, height: int = 26) -> Canvas:
    """Control tower: a glazed cab on a shaft, with a mast."""
    canvas = Canvas(width, height + 4)
    shaft = width // 2
    sx = (width - shaft) // 2
    canvas.rect(sx, 9, shaft, height - 9, "wall")
    canvas.vline(sx, 9, height - 1, "wall_light")
    # Cab, wider than the shaft and fully glazed.
    canvas.rect(0, 1, width, 9, "roof_hangar")
    canvas.rect(1, 3, width - 2, 4, "glass")
    canvas.hline(1, width - 2, 3, "glass_light")
    for x in range(3, width - 2, 4):
        canvas.vline(x, 3, 6, "metal_dark")
    canvas.hline(0, width - 1, 1, "metal_light")
    canvas.hline(0, width - 1, 9, "metal_dark")
    # Mast with a beacon.
    canvas.vline(width // 2, 0, 1, "metal")
    canvas.plot(width // 2, 0, "accent_red")
    canvas.rect(sx - 2, height, shaft + 4, 4, "concrete")
    canvas.outline()
    return canvas


def fuel_depot(width: int = 32, height: int = 22) -> Canvas:
    """Fuel farm: two tanks on a bunded pad with a pipe run."""
    canvas = Canvas(width, height)
    canvas.rect(0, 3, width, height - 5, "concrete")
    canvas.rect_outline(0, 3, width, height - 5, "accent_yellow")
    for index, cx in enumerate((9, 23)):
        canvas.ellipse(cx, 11, 7, 6, "metal")
        canvas.ellipse(cx, 9, 6, 4, "metal_light")
        canvas.ring(cx, 11, 6, "metal_dark")
        # Ladder up the side.
        canvas.vline(cx + 6, 8, 14, "metal_dark")
    # Pipe joining the tanks.
    canvas.hline(9, 23, 17, "metal_dark")
    canvas.plot(16, 17, "accent_red")
    canvas.outline()
    return canvas


def windsock(width: int = 14, height: int = 16) -> Canvas:
    """Windsock on a pole — the cheapest possible sign that an airfield is live."""
    canvas = Canvas(width, height)
    canvas.vline(2, 2, height - 1, "metal")
    canvas.plot(2, 2, "metal_light")
    # Cone, striped, streaming to the east.
    for i in range(9):
        top = 3 + i // 4
        bottom = 7 - i // 3
        colour = "accent_orange" if (i // 2) % 2 == 0 else "white"
        canvas.vline(4 + i, top, bottom, colour)
    canvas.outline()
    return canvas


def apron_light(width: int = 10, height: int = 18) -> Canvas:
    """Floodlight mast for the apron."""
    canvas = Canvas(width, height)
    canvas.vline(width // 2, 4, height - 1, "metal")
    canvas.vline(width // 2 + 1, 6, height - 1, "metal_dark")
    canvas.rect(1, 1, width - 2, 4, "metal_dark")
    canvas.hline(1, width - 2, 2, "accent_yellow")
    canvas.hline(1, width - 2, 1, "metal_light")
    canvas.outline()
    return canvas


def runway_sign(width: int = 16, height: int = 10) -> Canvas:
    """Mandatory-instruction sign at a taxiway hold."""
    canvas = Canvas(width, height)
    canvas.rect(0, 1, width, height - 4, "accent_red")
    canvas.rect_outline(0, 1, width, height - 4, "white")
    canvas.hline(4, 6, 4, "white")
    canvas.hline(9, 11, 4, "white")
    canvas.hline(0, width - 1, height - 3, "metal_dark")
    canvas.outline()
    return canvas


def fence(width: int = 32, height: int = 8) -> Canvas:
    """Perimeter fence run, tileable horizontally."""
    canvas = Canvas(width, height)
    canvas.hline(0, width - 1, 1, "metal")
    canvas.hline(0, width - 1, 4, "metal_dark")
    for x in range(0, width, 8):
        canvas.vline(x, 0, height - 2, "metal")
        canvas.plot(x, 0, "metal_light")
    return canvas


BUILDINGS: dict[str, callable] = {
    "terminal_1": lambda: terminal(80, 28, level=1),
    "terminal_2": lambda: terminal(112, 34, level=2),
    "terminal_3": lambda: terminal(160, 42, level=3),
    "hangar_small": lambda: hangar(56, 30),
    "cargo_shed": lambda: cargo_shed(48, 26),
    "tower": lambda: tower(20, 26),
    "fuel_depot": lambda: fuel_depot(32, 22),
}

## Small props that make a field look operated rather than drawn.
PROPS: dict[str, callable] = {
    "windsock": windsock,
    "apron_light": apron_light,
    "runway_sign": runway_sign,
    "fence": fence,
}


# ---------------------------------------------------------------------------
# Vehicles and people
# ---------------------------------------------------------------------------

def _vehicle(body: str, roof: str, length: int = 14, width: int = 8,
             beacon: bool = False, tank: bool = False) -> Canvas:
    """Top-down ground vehicle, nose east to match the aircraft convention."""
    canvas = Canvas(16, 16)
    x0 = (16 - length) // 2
    y0 = (16 - width) // 2
    canvas.rect(x0, y0, length, width, body)
    canvas.hline(x0, x0 + length - 1, y0, "metal_light")
    canvas.hline(x0, x0 + length - 1, y0 + width - 1, "metal_dark")
    # Cab with a windscreen, at the nose end.
    cab = 4
    canvas.rect(x0 + length - cab - 1, y0 + 1, cab, width - 2, roof)
    canvas.vline(x0 + length - 2, y0 + 1, y0 + width - 2, "glass_light")
    if tank:
        canvas.rect(x0 + 1, y0 + 1, length - cab - 3, width - 2, "metal")
        canvas.hline(x0 + 1, x0 + length - cab - 3, y0 + 1, "metal_light")
        canvas.hline(x0 + 1, x0 + length - cab - 3, y0 + width - 2, "metal_dark")
    if beacon:
        canvas.plot(x0 + length - cab - 1, y0 + width // 2, "accent_orange_light")
    # Wheels poking out on both sides.
    for wx in (x0 + 1, x0 + length - 4):
        canvas.hline(wx, wx + 1, y0 - 1, "asphalt_dark")
        canvas.hline(wx, wx + 1, y0 + width, "asphalt_dark")
    canvas.outline()
    return canvas


VEHICLES: dict[str, callable] = {
    "tug": lambda: _vehicle("accent_yellow", "wall", 11, 7, beacon=True),
    "fuel_truck": lambda: _vehicle("wall", "wall_light", 15, 8, tank=True),
    "baggage_cart": lambda: _vehicle("accent_teal", "roof_cargo", 12, 7),
}


def passenger(shirt: str = "accent_teal") -> Canvas:
    """An 8x12 traveller, seen from the side for the aircraft load view."""
    canvas = Canvas(8, 12)
    canvas.rect(2, 0, 4, 3, "sand_light")     # head
    canvas.plot(2, 1, "soil")
    canvas.plot(5, 1, "soil")
    canvas.rect(1, 3, 6, 5, shirt)            # torso
    canvas.hline(1, 6, 3, "white")
    canvas.rect(2, 8, 2, 3, "asphalt")        # legs
    canvas.rect(4, 8, 2, 3, "asphalt")
    canvas.outline()
    return canvas


def crate(kind: str = "box") -> Canvas:
    """A 12x12 cargo unit for the load view."""
    canvas = Canvas(12, 12)
    body, band = {
        "box": ("roof_cargo", "sand_light"),
        "mail": ("accent_teal", "white"),
        "medical": ("white", "accent_red"),
        "livestock": ("sand", "soil"),
    }.get(kind, ("roof_cargo", "sand_light"))
    canvas.rect(0, 1, 12, 10, body)
    canvas.hline(0, 11, 1, "wall_light")
    canvas.hline(0, 11, 10, "wall")
    canvas.hline(0, 11, 5, band)
    canvas.vline(5, 1, 10, band)
    canvas.outline()
    return canvas


def seated_passenger(shirt: str = "accent_teal", hair: str = "soil") -> Canvas:
    """A passenger seen through a cabin window: head and shoulders only.

    Sized to sit inside an 11px seat window. Anything more detailed than a head,
    hair and a collar is invisible at this size and just muddies the shape.
    """
    canvas = Canvas(9, 9)
    canvas.rect(2, 4, 5, 5, shirt)          # shoulders
    canvas.hline(2, 6, 4, "white")          # collar
    canvas.rect(2, 0, 5, 4, "sand_light")   # head
    canvas.hline(2, 6, 0, hair)             # hair
    canvas.plot(2, 1, hair)
    canvas.plot(6, 1, hair)
    canvas.plot(3, 2, "outline")            # eyes
    canvas.plot(5, 2, "outline")
    return canvas


def cabin_crate(kind: str = "box") -> Canvas:
    """A crate sized for a cargo bay slot."""
    canvas = Canvas(9, 9)
    body, band = {
        "box": ("roof_cargo", "sand_light"),
        "mail": ("accent_teal", "white"),
        "medical": ("white", "accent_red"),
        "livestock": ("sand", "soil"),
    }.get(kind, ("roof_cargo", "sand_light"))
    canvas.rect(0, 1, 9, 8, body)
    canvas.hline(0, 8, 1, "wall_light")
    canvas.hline(0, 8, 4, band)
    canvas.vline(4, 1, 8, band)
    canvas.rect_outline(0, 1, 9, 8, "outline")
    return canvas


PASSENGER_SHIRTS: list[str] = [
    "accent_teal", "accent_orange", "accent_green", "accent_red", "livery_light",
]
