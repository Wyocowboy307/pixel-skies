"""The locked Pixel Skies palette.

This is the single source of truth. docs/PIXEL_STYLE_GUIDE.md documents it and
data/world/palette.json exports it for the engine. No asset may use a colour
that is not in here.
"""

from __future__ import annotations

PALETTE: dict[str, str] = {
    # Water
    "water_deep": "#16293b",
    "water": "#1e4058",
    "water_shelf": "#2b5f7a",
    # Land
    "grass_dark": "#2c4634",
    "grass": "#3d6045",
    "grass_light": "#537a5a",
    "scrub": "#6b7a4a",
    "sand": "#8a7a52",
    "sand_light": "#a3926a",
    "soil": "#4a3d2c",
    # Cold
    "ice": "#b7cbd4",
    "ice_light": "#dfeaee",
    "tundra": "#68786e",
    # Surfaces
    "asphalt_dark": "#20262d",
    "asphalt": "#2f3740",
    "asphalt_light": "#414b56",
    "taxiway": "#4a545e",
    "concrete": "#5b646e",
    "concrete_light": "#727c87",
    # Structures
    "roof_terminal": "#7b6d5c",
    "roof_hangar": "#5e6a74",
    "roof_cargo": "#6a5f52",
    "wall": "#3f4750",
    "wall_light": "#59626c",
    # Metal and glass
    "metal_dark": "#39424c",
    "metal": "#6f7b86",
    "metal_light": "#9dabb5",
    "glass": "#2c4459",
    "glass_light": "#4c7391",
    # Livery and accents
    "livery_light": "#e8dfc6",
    "livery": "#cbbe9d",
    "livery_dark": "#9d906f",
    "accent_orange": "#e08b3c",
    "accent_orange_light": "#f2b167",
    "accent_teal": "#4fa3a8",
    "accent_red": "#c05a4a",
    "accent_yellow": "#d9b45a",
    "accent_green": "#7fb37a",
    # World map. A separate, brighter ramp: the sprite palette is deliberately
    # muted so aircraft read against terrain, but a whole planet drawn in it
    # looks grey and lifeless. These are the map's own colours.
    "map_ocean_deep": "#17527f",
    "map_ocean": "#2f86c2",
    "map_shelf": "#5cb4e0",
    "map_coast": "#0e3a58",
    "map_forest": "#2e7d4f",
    "map_grass": "#52a862",
    "map_grass_light": "#84c96f",
    "map_scrub": "#a8bd63",
    "map_desert": "#dcbb78",
    "map_desert_light": "#f0dda6",
    "map_mountain": "#8f7f6d",
    "map_mountain_light": "#c0b1a0",
    "map_tundra": "#a6bcab",
    "map_snow": "#eef6fa",
    "map_river": "#4aa3d6",
    # Bright game chrome. The management screens read as an admin panel in the
    # muted ramp; these are the saturated colours the game UI is built from.
    "hud_blue": "#3fa7dd",
    "hud_blue_deep": "#28709f",
    "card": "#fdf3da",
    "card_hi": "#fffdf2",
    "card_lo": "#e2cc9c",
    "navy": "#22374d",
    "navy_deep": "#162536",
    "btn_green": "#5cb84d",
    "btn_green_hi": "#93de77",
    "btn_green_lo": "#377f39",
    "btn_blue": "#4498dc",
    "btn_blue_hi": "#86c9f1",
    "btn_blue_lo": "#2d669f",
    "btn_red": "#d95c49",
    # Daylight. The detail screen stands the aircraft outside in good weather
    # rather than in a dark instrument bay.
    "sky": "#7fb6d1",
    "sky_light": "#a8d3e4",
    "sky_deep": "#5b93b3",
    # Warm UI. The cool navy panel ramp reads as a technical control program;
    # these are the friendlier surfaces the management layer sits on.
    "panel": "#e3d5b4",
    "panel_light": "#f2e8cd",
    "panel_shade": "#c2b08a",
    "panel_edge": "#8a7355",
    "panel_deep": "#5c4a35",
    "ink": "#33291d",
    "ink_soft": "#6b5a44",
    # Ink and UI
    "outline": "#0e141a",
    "shadow": "#1a2028",
    "ui_bg": "#111f29",
    "ui_bg_light": "#1b2f3c",
    "ui_border": "#33566a",
    "ui_border_light": "#4f7d94",
    "text": "#dfe9ec",
    "text_dim": "#8ba3b0",
    "white": "#eef4f6",
}


def rgb(key: str) -> tuple[int, int, int]:
    value = PALETTE[key]
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def rgba(key: str, alpha: int = 255) -> tuple[int, int, int, int]:
    return rgb(key) + (alpha,)


ALLOWED_RGB: frozenset[tuple[int, int, int]] = frozenset(rgb(k) for k in PALETTE)


# Alternate liveries reuse palette entries rather than inventing colours, so an
# airline's paint scheme can never drift outside the locked set.
LIVERIES: dict[str, dict[str, str]] = {
    "house": {
        "light": "livery_light",
        "base": "livery",
        "dark": "livery_dark",
        "trim": "accent_orange",
    },
    "sunrise": {
        "light": "accent_orange_light",
        "base": "accent_orange",
        "dark": "accent_red",
        "trim": "livery_light",
    },
    "alpine": {
        "light": "ice_light",
        "base": "metal_light",
        "dark": "metal",
        "trim": "accent_teal",
    },
}
