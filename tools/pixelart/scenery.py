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


def terminal(width: int = 96, height: int = 32) -> Canvas:
    canvas = _roofed_block(width, height, "roof_terminal", seed=8100, ribs=3)
    # Glazed frontage facing the apron, plus rooftop plant.
    canvas.rect(4, height - 4, width - 8, 2, "glass")
    canvas.hline(4, width - 5, height - 4, "glass_light")
    canvas.rect(width - 22, 4, 10, 6, "roof_hangar")
    canvas.hline(width - 22, width - 13, 4, "metal_light")
    canvas.outline()
    return canvas


def hangar(width: int = 64, height: int = 34) -> Canvas:
    canvas = _roofed_block(width, height, "roof_hangar", seed=8200, ribs=0)
    # Arched roof read as three bands, and the big door on the apron side.
    canvas.rect(2, 2, width - 4, 4, "metal_light")
    canvas.rect(2, height - 10, width - 4, 6, "wall")
    canvas.rect(6, height - 4, width - 12, 3, "asphalt_dark")
    for x in range(8, width - 8, 6):
        canvas.vline(x, height - 3, height - 2, "metal_dark")
    canvas.outline()
    return canvas


def cargo_shed(width: int = 48, height: int = 28) -> Canvas:
    canvas = _roofed_block(width, height, "roof_cargo", seed=8300, ribs=2)
    canvas.rect(4, height - 5, width - 8, 3, "asphalt_dark")
    canvas.outline()
    return canvas


def tower(width: int = 20, height: int = 20) -> Canvas:
    canvas = Canvas(width, height + 4)
    canvas.rect(3, 6, width - 6, height - 6, "wall")
    canvas.rect(1, 0, width - 2, 8, "roof_hangar")
    # Glazed cab — the one thing that says "control tower" from above.
    canvas.rect(2, 1, width - 4, 4, "glass")
    canvas.hline(2, width - 3, 1, "glass_light")
    canvas.hline(1, width - 2, 0, "metal_light")
    canvas.rect(3, height - 2, width - 6, 4, "wall")
    canvas.outline()
    return canvas


def fuel_depot(width: int = 28, height: int = 20) -> Canvas:
    canvas = Canvas(width, height)
    canvas.rect(0, 4, width, height - 6, "concrete")
    for i, cx in enumerate((8, 20)):
        canvas.ellipse(cx, 11, 6, 5, "metal")
        canvas.ellipse(cx, 9, 5, 3, "metal_light")
        canvas.hline(cx - 5, cx + 4, 15, "metal_dark")
    canvas.outline()
    return canvas


BUILDINGS: dict[str, callable] = {
    "terminal_1": lambda: terminal(80, 28),
    "terminal_2": lambda: terminal(112, 34),
    "terminal_3": lambda: terminal(160, 42),
    "hangar_small": lambda: hangar(56, 30),
    "cargo_shed": lambda: cargo_shed(48, 26),
    "tower": lambda: tower(20, 20),
    "fuel_depot": lambda: fuel_depot(28, 20),
}


# ---------------------------------------------------------------------------
# Vehicles and people
# ---------------------------------------------------------------------------

def _vehicle(body: str, roof: str, length: int = 14, width: int = 8) -> Canvas:
    """Top-down vehicle, nose east to match the aircraft convention."""
    canvas = Canvas(16, 16)
    x0 = (16 - length) // 2
    y0 = (16 - width) // 2
    canvas.rect(x0, y0, length, width, body)
    canvas.hline(x0, x0 + length - 1, y0, "metal_light")
    canvas.hline(x0, x0 + length - 1, y0 + width - 1, "metal_dark")
    canvas.rect(x0 + length - 6, y0 + 1, 4, width - 2, roof)
    # Wheels poking out on both sides.
    for wx in (x0 + 2, x0 + length - 4):
        canvas.hline(wx, wx + 1, y0 - 1, "asphalt_dark")
        canvas.hline(wx, wx + 1, y0 + width, "asphalt_dark")
    canvas.outline()
    return canvas


VEHICLES: dict[str, callable] = {
    "tug": lambda: _vehicle("accent_yellow", "glass", 11, 7),
    "fuel_truck": lambda: _vehicle("metal", "glass", 14, 8),
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
