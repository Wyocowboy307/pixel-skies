"""The locked Pixel Skies PixelLab specification.

This file is the contract. Every production asset is generated from an entry
here, with the shared style clauses appended, so no asset can drift into its own
visual direction — which is the whole point of moving generation off ad-hoc
prompting and into a pipeline.

Changing STYLE or NEGATIVE invalidates the whole set: if they change, everything
gets regenerated, not just the next asset.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Locked style clauses, appended to every prompt.
# ---------------------------------------------------------------------------

STYLE = (
    "chunky toy-like pixel art game asset, compact and slightly exaggerated "
    "proportions, bold readable silhouette, flat three-tone shading, one dark "
    "outline, warm muted palette, crisp hard pixel edges, charming and "
    "collectible, light from the upper left"
)

NEGATIVE = (
    "photorealistic, 3d render, painterly, soft brush, blurry, anti-aliased, "
    "gradient, colour banding, glow, noisy dithering, technical diagram, "
    "blueprint, schematic, cluttered detail, rivets, text, letters, numbers, "
    "logo, watermark, drop shadow, realistic proportions, long thin fuselage, "
    "many wheels, landing gear bogies, facing left, jet engines, closed windows, portholes, isometric, three-quarter view, 3d perspective, vanishing point"
)

# Structured controls, chosen to match docs/PIXEL_STYLE_GUIDE.md exactly.
BASE = {
    "outline": "single color black outline",   # the guide allows one outline colour
    "shading": "flat shading",                 # three steps maximum, no ramps
    "detail": "low detail",                    # consistency beats detail
    "no_background": True,                     # binary alpha, transparent ground
    "text_guidance_scale": 7.5,
    # Style reference weight when a locked reference is supplied.
    "style_strength": 55.0,
}


@dataclass(frozen=True)
class AssetSpec:
    """One production asset."""

    key: str                    # stable id, also the candidate filename
    logical: str                # destination path under assets/art/production/
    prompt: str
    size: tuple[int, int]
    view: str                   # 'side' | 'high top-down' | 'low top-down'
    direction: str | None = None
    detail: str | None = None
    shading: str | None = None
    coverage: float | None = None
    ## Assets that define the look. Generated first, approved by eye, then used
    ## as the style reference for everything after them.
    is_reference: bool = False
    notes: str = ""

    def params(self) -> dict:
        out = dict(BASE)
        out["description"] = f"{self.prompt}, {STYLE}"
        out["negative_description"] = NEGATIVE
        out["image_size"] = {"width": self.size[0], "height": self.size[1]}
        out["view"] = self.view
        if self.direction:
            out["direction"] = self.direction
        if self.detail:
            out["detail"] = self.detail
        if self.shading:
            out["shading"] = self.shading
        if self.coverage is not None:
            out["coverage_percentage"] = self.coverage
        return out


# ---------------------------------------------------------------------------
# The starter set. Deliberately small: nothing else is generated until these are
# cohesive in the running game.
# ---------------------------------------------------------------------------

STARTER: list[AssetSpec] = [
    # -- Aircraft ----------------------------------------------------------
    AssetSpec(
        key="trailhopper_side",
        logical="aircraft/trailhopper_4/trailhopper_4_side.png",
        prompt=(
            "side view of a tiny chunky cartoon bush aeroplane facing right, "
            "propeller and round nose at the right edge, tall tail fin at the "
            "left edge, stubby rounded fuselage twice as long as it is tall, "
            "open cutaway fuselage showing a bright white cabin interior with "
            "a row of four empty orange passenger seats, high wing, exactly "
            "two fat black wheels on short legs, cream body with an orange "
            "belly stripe, flat blocks of solid colour with no gradients"
        ),
        size=(128, 96), view="side", direction="west", coverage=86.0,
        is_reference=True,
        notes="THE reference asset. Everything else is style-matched to this one.",
    ),
    AssetSpec(
        key="trailhopper_top",
        logical="aircraft/trailhopper_4/trailhopper_4_top.png",
        prompt=(
            "top-down view of a tiny chunky cartoon bush aeroplane, single "
            "propeller at the nose, straight high wings, short fuselage, small "
            "tailplane, cream and orange livery, nose pointing east"
        ),
        size=(64, 64), view="high top-down", direction="east", coverage=82.0,
        notes="Must read as the same aircraft as trailhopper_side.",
    ),
    AssetSpec(
        key="twinwing_side",
        logical="aircraft/twinwing_8/twinwing_8_side.png",
        prompt=(
            "side view of a chunky cartoon twin-engine utility aeroplane, stubby "
            "rounded fuselage, two propeller engines slung under a low wing, "
            "tricycle landing gear, six square passenger windows, big tail fin, "
            "cream and orange livery, nose pointing right"
        ),
        size=(160, 96), view="side", direction="east", coverage=88.0,
        notes="Same family as the Trailhopper: longer, low wing, two engines.",
    ),
    AssetSpec(
        key="twinwing_top",
        logical="aircraft/twinwing_8/twinwing_8_top.png",
        prompt=(
            "top-down view of a chunky cartoon twin-engine utility aeroplane, "
            "two propeller nacelles on straight low wings, short fuselage, "
            "cream and orange livery, nose pointing east"
        ),
        size=(80, 80), view="high top-down", direction="east", coverage=82.0,
    ),
    # -- Airport props -----------------------------------------------------
    AssetSpec(
        key="terminal",
        logical="airports/buildings/terminal_1.png",
        prompt=(
            "directly overhead flat top-down orthographic view of a small "
            "friendly airport terminal building, flat rectangular roof filling "
            "the frame, roof vents and skylights seen from straight above, thin "
            "glazed frontage strip along the bottom edge, warm sandy colours"
        ),
        size=(96, 48), view="high top-down", coverage=90.0,
    ),
    AssetSpec(
        key="hangar",
        logical="airports/buildings/hangar_small.png",
        prompt=(
            "top-down view of a small aircraft hangar, curved corrugated metal "
            "roof, wide sliding door on one side, grey blue metal"
        ),
        size=(64, 48), view="high top-down", coverage=90.0,
    ),
    AssetSpec(
        key="baggage_cart",
        logical="airports/vehicles/baggage_cart.png",
        prompt=(
            "top-down view of a tiny airport baggage cart with a flat bed and "
            "stacked suitcases, chunky wheels, teal paint"
        ),
        size=(24, 24), view="high top-down", direction="east", coverage=78.0,
    ),
    AssetSpec(
        key="fuel_truck",
        logical="airports/vehicles/fuel_truck.png",
        prompt=(
            "top-down view of a tiny airport fuel bowser truck, cylindrical tank "
            "on the back, small cab, chunky wheels, white and red"
        ),
        size=(24, 24), view="high top-down", direction="east", coverage=78.0,
    ),
    AssetSpec(
        key="crate",
        logical="cargo/crate_box.png",
        prompt=(
            "a single small wooden cargo crate with plank seams and a paper "
            "shipping label, warm brown timber"
        ),
        size=(16, 16), view="side", coverage=82.0,
    ),
    # -- UI icons ----------------------------------------------------------
    AssetSpec(
        key="icon_passenger",
        logical="ui/icons/passenger.png",
        prompt=(
            "simple game UI icon of a single passenger, head and shoulders "
            "silhouette, teal shirt, bold and readable at very small size"
        ),
        size=(16, 16), view="side", detail="low detail", coverage=80.0,
    ),
    AssetSpec(
        key="icon_cargo",
        logical="ui/icons/cargo.png",
        prompt=(
            "simple game UI icon of a stacked cargo box with a strap, warm "
            "brown, bold and readable at very small size"
        ),
        size=(16, 16), view="side", detail="low detail", coverage=80.0,
    ),
    AssetSpec(
        key="icon_fuel",
        logical="ui/icons/fuel.png",
        prompt=(
            "simple game UI icon of a fuel jerrycan with a spout and handle, "
            "teal, bold and readable at very small size"
        ),
        size=(16, 16), view="side", detail="low detail", coverage=80.0,
    ),
    AssetSpec(
        key="icon_route",
        logical="ui/icons/route.png",
        prompt=(
            "simple game UI icon of a route: two map pins joined by a dashed "
            "curved line, orange, bold and readable at very small size"
        ),
        size=(16, 16), view="side", detail="low detail", coverage=80.0,
    ),
]


STARTER.append(AssetSpec(
    key="cloud",
    logical="world/cloud_1.png",
    prompt=(
        "a single fluffy cartoon cloud, flat bottom, puffy rounded top, pure "
        "white with pale ice-blue shading underneath, chunky and simple"
    ),
    size=(36, 16), view="side", detail="low detail", coverage=86.0,
))


def by_key(key: str) -> AssetSpec | None:
    for spec in STARTER:
        if spec.key == key:
            return spec
    return None


def reference_spec() -> AssetSpec:
    for spec in STARTER:
        if spec.is_reference:
            return spec
    return STARTER[0]
