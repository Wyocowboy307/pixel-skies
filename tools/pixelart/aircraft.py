"""Aircraft sprite generation.

Each family is described once in **metres**, and both the top and the side view
are derived from that single description. Proportions therefore cannot drift
between the two views — which is one of the art bible's explicit rejection
rules — and the three families stay consistently scaled against each other.

Local convention: the nose points east (+x); the engine rotates the sprite.
Light comes from the upper left, so in top view the -y side of a surface is lit
and the +y side is shadowed; in side view the top is lit and the belly shadowed.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from .canvas import Canvas
from .palette import LIVERIES


@dataclass(frozen=True)
class AircraftSpec:
    """One aircraft family, in metres, plus its output canvases."""

    key: str
    name: str
    length_m: float
    span_m: float
    fuselage_width_m: float
    fuselage_height_m: float
    wing_chord_m: float
    wing_x_frac: float          # wing leading edge, as a fraction of length aft of the nose
    high_wing: bool
    tail_span_m: float
    tail_chord_m: float
    fin_height_m: float         # above the fuselage top
    prop_diameter_m: float
    engines: int
    wing_engines: bool
    engine_span_frac: float     # nacelle position as a fraction of half-span
    cabin_windows: int
    gear: str                   # tricycle | taildragger
    gear_height_m: float
    canvas_top: int
    canvas_side: tuple[int, int]
    livery: str = "house"
    struts: bool = False
    ## A T-tail puts the tailplane on top of the fin. It is the single strongest
    ## silhouette cue available at this sprite size, so only one family has one.
    t_tail: bool = False


SPECS: dict[str, AircraftSpec] = {
    # Bush single: strutted high wing, big prop, tail-dragger stance.
    "trailhopper_4": AircraftSpec(
        key="trailhopper_4", name="Trailhopper 4",
        length_m=8.3, span_m=11.0, fuselage_width_m=1.2, fuselage_height_m=1.45,
        wing_chord_m=1.45, wing_x_frac=0.33, high_wing=True,
        tail_span_m=3.4, tail_chord_m=1.05, fin_height_m=1.15,
        prop_diameter_m=1.9, engines=1, wing_engines=False, engine_span_frac=0.0,
        cabin_windows=2, gear="taildragger", gear_height_m=0.75,
        canvas_top=48, canvas_side=(128, 48), struts=True,
    ),
    # Low-wing utility twin: a different silhouette from the other two on
    # purpose, so the fleet does not read as one aircraft in three sizes.
    "twinwing_8": AircraftSpec(
        key="twinwing_8", name="Twinwing 8",
        length_m=10.6, span_m=12.4, fuselage_width_m=1.5, fuselage_height_m=1.7,
        wing_chord_m=1.8, wing_x_frac=0.40, high_wing=False,
        tail_span_m=4.6, tail_chord_m=1.35, fin_height_m=1.5,
        prop_diameter_m=2.0, engines=2, wing_engines=True, engine_span_frac=0.34,
        cabin_windows=4, gear="tricycle", gear_height_m=0.85,
        canvas_top=64, canvas_side=(176, 64),
    ),
    # Commuter turboprop: high wing, tall gear, long cabin.
    "highline_19": AircraftSpec(
        key="highline_19", name="Highline 19",
        length_m=15.8, span_m=19.8, fuselage_width_m=2.0, fuselage_height_m=2.2,
        wing_chord_m=2.2, wing_x_frac=0.34, high_wing=True,
        tail_span_m=6.9, tail_chord_m=1.9, fin_height_m=2.3,
        prop_diameter_m=2.6, engines=2, wing_engines=True, engine_span_frac=0.30,
        cabin_windows=7, gear="tricycle", gear_height_m=1.0,
        canvas_top=96, canvas_side=(240, 88), t_tail=True,
    ),
}


def _livery(name: str) -> dict[str, str]:
    return LIVERIES.get(name, LIVERIES["house"])


def _shade(offset: int, half: int, light: str, base: str, dark: str) -> str:
    """Three-step shading across a form. Upper-left light: low offsets are lit."""
    if half <= 1:
        return base
    edge = max(1, half // 3)
    if offset <= -half + edge:
        return light
    if offset >= half - edge:
        return dark
    return base


# ---------------------------------------------------------------------------
# Top view
# ---------------------------------------------------------------------------

def build_top(spec: AircraftSpec) -> Canvas:
    size = spec.canvas_top
    canvas = Canvas(size, size)
    livery = _livery(spec.livery)
    # Scale so the larger of length/span fills the canvas with a 3 px margin for
    # the outline, keeping every family on one consistent scale ladder.
    ppm = (size - 6) / max(spec.length_m, spec.span_m)
    axis = size // 2
    length = round(spec.length_m * ppm)
    nose = (size + length) // 2 - 1
    tail = nose - length

    ctx = dict(ppm=ppm, axis=axis, nose=nose, tail=tail, length=length, livery=livery)

    _top_wing(canvas, spec, ctx)
    _top_tail(canvas, spec, ctx)
    _top_fuselage(canvas, spec, ctx)
    if spec.high_wing:
        # A high wing passing over the fuselage is the only cue that separates it
        # from a low wing when seen from directly above.
        _top_wing(canvas, spec, ctx)
        if spec.struts:
            _top_struts(canvas, spec, ctx)
    _top_engines(canvas, spec, ctx)
    _top_glass(canvas, spec, ctx)

    canvas.mirror_y(axis)
    _top_trim(canvas, spec, ctx)
    canvas.outline()
    return canvas


def _top_fuselage(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    livery = ctx["livery"]
    half_max = max(2, round(spec.fuselage_width_m * ctx["ppm"] * 0.5))
    nose, tail, length = ctx["nose"], ctx["tail"], ctx["length"]
    nose_run = max(2, int(length * 0.16))
    boom_start = int(length * 0.62)
    for x in range(tail, nose + 1):
        back = nose - x
        if back < nose_run:
            # Cowl narrows toward the nose — a nose that widens forward reads as
            # a trumpet, not an aeroplane.
            half = max(1, round(half_max * (0.42 + 0.58 * back / nose_run)))
        elif back > boom_start:
            run = (back - boom_start) / max(1, length - boom_start)
            half = max(1, round(half_max * (1.0 - 0.55 * run)))
        else:
            half = half_max
        for dy in range(-half, half + 1):
            canvas.plot(x, ctx["axis"] + dy,
                        _shade(dy, half, livery["light"], livery["base"], livery["dark"]))


def _top_wing(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    livery = ctx["livery"]
    ppm, nose, axis = ctx["ppm"], ctx["nose"], ctx["axis"]
    half_span = round(spec.span_m * ppm * 0.5)
    chord = max(3, round(spec.wing_chord_m * ppm))
    leading = nose - round(spec.length_m * spec.wing_x_frac * ppm)
    tip_round = max(1, half_span // 8)
    for dy in range(0, half_span + 1):
        t = dy / max(1, half_span)
        # Taper only, no sweep: at this sprite size a swept leading edge turns
        # into a staircase of single pixels that reads as damage.
        tip_chord = max(2, round(chord * (1.0 - 0.30 * t)))
        x_lead = leading
        # Round the last few rows in from the leading edge so the tip is a tip
        # rather than a square-cut plank.
        if half_span - dy < tip_round:
            inset = tip_round - (half_span - dy)
            x_lead -= inset
            tip_chord = max(1, tip_chord - inset)
        x_trail = x_lead - tip_chord
        for x in range(x_trail, x_lead + 1):
            if x >= x_lead - 1:
                colour = livery["light"]        # lit leading edge
            elif x <= x_trail + 1:
                colour = livery["dark"]         # shadowed trailing edge
            else:
                colour = livery["base"]
            canvas.plot(x, axis - dy, colour)


def _top_tail(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    livery = ctx["livery"]
    ppm, nose, axis, tail = ctx["ppm"], ctx["nose"], ctx["axis"], ctx["tail"]
    half_span = max(2, round(spec.tail_span_m * ppm * 0.5))
    chord = max(2, round(spec.tail_chord_m * ppm))
    leading = tail + chord + max(1, round(ctx["length"] * 0.04))
    if spec.t_tail:
        # Sitting on the fin, the tailplane is further aft and reads wider.
        half_span = round(half_span * 1.15)
        leading = tail + chord
    for dy in range(0, half_span + 1):
        t = dy / max(1, half_span)
        tip_chord = max(2, round(chord * (1.0 - 0.28 * t)))
        for x in range(leading - tip_chord, leading + 1):
            if x >= leading - 1:
                colour = livery["light"]
            elif x <= leading - tip_chord + 1:
                colour = livery["dark"]
            else:
                colour = livery["base"]
            canvas.plot(x, axis - dy, colour)
    # Fin: almost edge-on from above, so it reads as a short spine at the tail.
    for x in range(tail, leading):
        run = (x - tail) / max(1, leading - tail)
        half = 1 if run < 0.65 else 0
        for dy in range(-half, half + 1):
            canvas.plot(x, axis + dy, livery["dark"])


def _top_engines(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    ppm, nose, axis = ctx["ppm"], ctx["nose"], ctx["axis"]
    prop_half = max(3, round(spec.prop_diameter_m * ppm * 0.5))
    if spec.wing_engines:
        half_span = round(spec.span_m * ppm * 0.5)
        offset = round(half_span * spec.engine_span_frac * 2.0)
        leading = nose - round(spec.length_m * spec.wing_x_frac * ppm)
        chord = max(3, round(spec.wing_chord_m * ppm))
        centre = axis - offset
        nacelle_half = max(2, round(spec.fuselage_width_m * ppm * 0.28))
        front = leading + round(chord * 0.75)
        for x in range(leading - chord, front + 1):
            for dy in range(-nacelle_half, nacelle_half + 1):
                canvas.plot(x, centre + dy,
                            _shade(dy, nacelle_half, "metal_light", "metal", "metal_dark"))
        _top_prop(canvas, front + 1, centre, prop_half)
    else:
        cowl = max(2, round(ctx["length"] * 0.12))
        half_max = max(2, round(spec.fuselage_width_m * ppm * 0.5))
        for x in range(nose - cowl, nose + 1):
            back = nose - x
            half = max(1, round(half_max * (0.5 + 0.5 * back / cowl)))
            for dy in range(-half, half + 1):
                canvas.plot(x, axis + dy,
                            _shade(dy, half, "metal_light", "metal", "metal_dark"))
        _top_prop(canvas, nose + 1, axis, prop_half)


def _top_prop(canvas: Canvas, x: int, axis: int, half: int) -> None:
    """Stopped two-blade propeller: a thin blade tapering to the tips with a
    bright spinner at the hub, so it never reads as a solid slab."""
    for dy in range(-half, half + 1):
        t = abs(dy) / max(1, half)
        canvas.plot(x, axis + dy, "metal_light" if dy < 0 else "metal_dark")
        if t < 0.45:
            canvas.plot(x - 1, axis + dy, "metal")
    canvas.plot(x - 1, axis, "metal_light")
    canvas.plot(x, axis, "metal_light")


def _top_struts(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    ppm, nose, axis = ctx["ppm"], ctx["nose"], ctx["axis"]
    chord = max(3, round(spec.wing_chord_m * ppm))
    leading = nose - round(spec.length_m * spec.wing_x_frac * ppm)
    x = leading - chord // 2
    body_half = max(2, round(spec.fuselage_width_m * ppm * 0.5))
    tip = round(spec.span_m * ppm * 0.5 * 0.55)
    for dy in range(body_half + 1, tip):
        canvas.plot(x, axis - dy, "metal_dark")


def _top_glass(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    nose, length, axis = ctx["nose"], ctx["length"], ctx["axis"]
    half = max(1, round(spec.fuselage_width_m * ctx["ppm"] * 0.5) - 1)
    front = nose - max(2, int(length * 0.17))
    back = front - max(2, int(length * 0.11))
    for x in range(back, front + 1):
        for dy in range(-half, half + 1):
            canvas.plot(x, axis + dy, "glass_light" if dy < 0 else "glass")


def _top_trim(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """A single trim line along the spine — the airline's colour, readable even
    when the sprite is only a few pixels across."""
    livery = ctx["livery"]
    nose, tail, length, axis = ctx["nose"], ctx["tail"], ctx["length"], ctx["axis"]
    half = max(2, round(spec.fuselage_width_m * ctx["ppm"] * 0.5))
    for x in range(tail + max(2, length // 6), nose - int(length * 0.34)):
        # Offset off the centreline and doubled, so it reads as paint rather
        # than as a seam down the middle of the fuselage.
        canvas.plot(x, axis + half - 1, livery["trim"])
        canvas.plot(x, axis - half + 1, livery["trim"])


# ---------------------------------------------------------------------------
# Side view
# ---------------------------------------------------------------------------
#
# The side view is deliberately NOT derived from the metric spec the way the top
# view is. Real fuselage ratios are 6:1 or worse, and at sprite size that reads
# as a technical reference drawing rather than as an aircraft you own. These are
# toys: stubby, round-nosed, chunky-tailed, with proportions hand-tuned per
# family. The metric spec still governs the top view, and the two agree on the
# things that carry identity — wing position, engine count and layout, gear
# type, livery — which is what keeps them the same aircraft.


@dataclass(frozen=True)
class SideStyle:
    """Stylized side-profile proportions, in pixels."""

    canvas: tuple[int, int]
    body_length: int
    body_height: int
    ## Where the round nose begins, as a fraction of length from the tail.
    nose_start: float
    ## Where the tail cone begins, as a fraction of length from the tail.
    tail_end: float
    ## How much of the body height survives at the very tail. Toy planes keep a
    ## chunky tail rather than tapering to a needle.
    tail_keep: float
    fin_height: int
    fin_root: int
    windows: int
    window_size: int
    wing_chord: int
    wing_x: float               # wing leading edge, fraction of length aft of nose
    gear_height: int
    wheel_radius: int
    prop_radius: int
    ## Nose-up stance, in pixels of drop at the tail. A tail-dragger sitting
    ## nose-high is instantly readable as a bush aircraft, and it is what stops
    ## the three families reading as one shape in three sizes.
    rake: int = 0


SIDE_STYLES: dict[str, SideStyle] = {
    # Sizes are chosen so the detail view can draw these at 1:1 against a
    # 640x360 screen. Scaling a sprite up to fill the screen would make its
    # pixels coarser than the UI around it; drawing it big natively keeps one
    # pixel density everywhere and leaves room for real detail.
    #
    # The body ratio carries the size tier: small is roundest, large longest.

    # Small: roundest and stubbiest — almost an egg with wings. 2.5:1.
    "trailhopper_4": SideStyle(
        canvas=(208, 120), body_length=150, body_height=58,
        nose_start=0.84, tail_end=0.40, tail_keep=0.30,
        fin_height=38, fin_root=42, windows=3, window_size=12,
        wing_chord=42, wing_x=0.40, gear_height=18, wheel_radius=11, prop_radius=26,
        rake=11,
    ),
    # Medium: longer body, same chunk. 2.9:1.
    "twinwing_8": SideStyle(
        canvas=(264, 144), body_length=205, body_height=68,
        nose_start=0.84, tail_end=0.38, tail_keep=0.28,
        fin_height=46, fin_root=54, windows=5, window_size=12,
        wing_chord=52, wing_x=0.44, gear_height=20, wheel_radius=10, prop_radius=27,
    ),
    # Large: longest and tallest, a proper little airliner. 3.3:1.
    "highline_19": SideStyle(
        canvas=(320, 176), body_length=270, body_height=80,
        nose_start=0.85, tail_end=0.36, tail_keep=0.26,
        fin_height=58, fin_root=66, windows=8, window_size=14,
        wing_chord=62, wing_x=0.42, gear_height=24, wheel_radius=12, prop_radius=30,
    ),
}


def side_style(spec: AircraftSpec) -> SideStyle:
    return SIDE_STYLES[spec.key]


def _capsule(style: SideStyle, body_top: int, belly: int) -> list[tuple[int, int]]:
    """Top and bottom of the fuselage for each station along its length.

    The nose is a circular bulge rather than a taper — that roundness is most of
    what makes the aircraft read as a toy instead of a diagram.
    """
    profile: list[tuple[int, int]] = []
    height = float(belly - body_top)
    for i in range(style.body_length):
        t = i / float(style.body_length - 1)     # 0 at tail, 1 at nose
        # Rake drops the tail toward the ground, tipping the nose up.
        lift = style.rake * (1.0 - t)
        top = float(body_top) + lift
        bottom = float(belly) + lift
        if t >= style.nose_start:
            run = (t - style.nose_start) / max(1e-6, 1.0 - style.nose_start)
            # Circular falloff: fat almost all the way forward, then a quick round.
            drop = (1.0 - math.sqrt(max(0.0, 1.0 - run * run))) * height * 0.5
            top += drop * 1.05
            bottom -= drop * 0.62
        elif t <= style.tail_end:
            run = 1.0 - t / max(1e-6, style.tail_end)
            keep = 1.0 - (1.0 - style.tail_keep) * run
            centre = (body_top + belly) * 0.5 + lift - height * 0.16 * run
            top = centre - height * keep * 0.5
            bottom = centre + height * keep * 0.5
        profile.append((int(round(top)), int(round(bottom))))
    return profile


def build_side(spec: AircraftSpec) -> Canvas:
    style = side_style(spec)
    width, height = style.canvas
    canvas = Canvas(width, height)
    livery = _livery(spec.livery)

    baseline = height - 2
    belly = baseline - style.gear_height
    body_top = belly - style.body_height
    nose = (width + style.body_length) // 2 - 1
    tail = nose - style.body_length + 1
    profile = _capsule(style, body_top, belly)

    ctx = dict(style=style, livery=livery, nose=nose, tail=tail, belly=belly,
               body_top=body_top, baseline=baseline, profile=profile)

    _side_tail(canvas, spec, ctx)
    if not spec.high_wing:
        _side_wing(canvas, spec, ctx)
    _side_body(canvas, spec, ctx)
    if spec.high_wing:
        _side_wing(canvas, spec, ctx)
    _side_glass(canvas, spec, ctx)
    _side_engines(canvas, spec, ctx)
    _side_gear(canvas, spec, ctx)
    canvas.outline()
    return canvas


def _station(ctx: dict, x: int) -> tuple[int, int]:
    """Fuselage top and bottom at screen station `x`.

    The profile is built tail-to-nose (index 0 is the tail), so it is indexed
    from the tail — indexing it from the nose puts the round nose on the tail.
    """
    profile: list = ctx["profile"]
    index = max(0, min(len(profile) - 1, x - ctx["tail"]))
    return profile[index]


def _side_body(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    livery = ctx["livery"]
    style: SideStyle = ctx["style"]
    nose, tail = ctx["nose"], ctx["tail"]
    for x in range(tail, nose + 1):
        top, bottom = _station(ctx, x)
        for y in range(top, bottom + 1):
            offset = y - (top + bottom) // 2
            half = max(1, (bottom - top) // 2)
            canvas.plot(x, y, _shade(offset, half, livery["light"], livery["base"], livery["dark"]))
    # A bold stripe along the flank: the airline's colour, and the detail that
    # stops the fuselage reading as a blank capsule.
    stripe_y = ctx["body_top"] + int(round(style.body_height * 0.55))
    thickness = max(1, style.body_height // 22)
    for x in range(tail + 2, nose - 2):
        top, bottom = _station(ctx, x)
        y = min(max(stripe_y, top + 2), bottom - 3)
        for dy in range(thickness):
            canvas.plot(x, y + dy, livery["trim"])
    _side_door(canvas, spec, ctx)


def _side_door(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """A passenger door, and a cargo door on anything that carries freight.

    At this sprite size the flank is the largest flat area on the aircraft;
    a door is what gives it scale and tells you people get in there.
    """
    livery = ctx["livery"]
    style: SideStyle = ctx["style"]
    nose = ctx["nose"]
    door_h = max(6, int(round(style.body_height * 0.52)))
    door_w = max(4, int(round(style.body_length * 0.055)))
    x0 = nose - int(round(style.body_length * 0.34))
    top, bottom = _station(ctx, x0)
    y0 = ctx["body_top"] + int(round(style.body_height * 0.22))
    y0 = min(y0, bottom - door_h - 1)
    canvas.rect_outline(x0 - door_w, y0, door_w, door_h, livery["dark"])
    canvas.vline(x0 - door_w, y0 + 1, y0 + door_h - 2, livery["light"])
    # Handle.
    canvas.plot(x0 - 2, y0 + door_h // 2, "metal_dark")

    if spec.cabin_windows >= 4:
        cargo_w = max(6, int(round(style.body_length * 0.10)))
        cx = nose - int(round(style.body_length * 0.62))
        c_top, c_bottom = _station(ctx, cx)
        cy = ctx["body_top"] + int(round(style.body_height * 0.34))
        cy = min(cy, c_bottom - door_h)
        canvas.rect_outline(cx - cargo_w, cy, cargo_w, max(5, door_h - 3), livery["dark"])


def _side_wing(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """Edge-on the wing is a thick chunky blade. Its height on the fuselage is
    what tells a high wing from a low one, and it matches the top view."""
    livery = ctx["livery"]
    style: SideStyle = ctx["style"]
    leading = ctx["nose"] - int(round(style.body_length * style.wing_x))
    chord = style.wing_chord
    thickness = max(3, style.body_height // 6)
    y = ctx["body_top"] - thickness + 2 if spec.high_wing else ctx["belly"] - thickness - 1
    for x in range(leading - chord, leading + 1):
        run = (leading - x) / max(1, chord)
        rows = thickness if run < 0.6 else max(2, thickness - 1)
        for dy in range(rows):
            colour = livery["light"] if dy == 0 else (
                livery["dark"] if dy == rows - 1 else livery["base"])
            canvas.plot(x, y + dy, colour)
    # No dark run under the wing root: against the fuselage it reads as a gap
    # between the two rather than as a join.
    # No wing strut in side view: at this stylization a diagonal line across the
    # flank reads as a scratch, and the high wing is already legible from the
    # blade sitting on the roof.


def _side_tail(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """A tall fin that grows out of the tail cone.

    The fin's leading edge is the one nearest the nose and sweeps up and back;
    the trailing edge is vertical at the very tail. Drawn as a plain slab it
    reads as a sail stuck on the back, so the top is narrowed and rounded.
    """
    livery = ctx["livery"]
    style: SideStyle = ctx["style"]
    tail = ctx["tail"]
    body_top = ctx["body_top"]
    root = style.fin_root
    # Anchored to the raked tail so the fin does not float when the nose lifts.
    body_top = body_top + int(round(style.rake))
    top_y = body_top - style.fin_height

    for x in range(tail, tail + root + 1):
        # 0 at the leading edge (nearest the nose), 1 at the trailing edge.
        run = (tail + root - x) / float(max(1, root))
        rise = min(1.0, run / (0.52 if spec.t_tail else 0.72))
        y_top = int(round(body_top - style.fin_height * rise))
        # Round the very top, except on a T-tail where the plateau carries the
        # tailplane and must stay flat.
        if run > 0.86 and not spec.t_tail:
            y_top += int(round((run - 0.86) / 0.14 * 2.0))
        _, bottom = _station(ctx, min(x, ctx["nose"]))
        y_bottom = min(body_top + 3, bottom)
        for y in range(y_top, y_bottom + 1):
            colour = livery["light"] if y <= y_top + 1 else livery["base"]
            canvas.plot(x, y, colour)

    # Livery flash across the fin, following its sweep.
    for x in range(tail + 1, tail + root - 1):
        run = (tail + root - x) / float(max(1, root))
        rise = min(1.0, run / 0.72)
        y = int(round(body_top - style.fin_height * rise * 0.58))
        canvas.plot(x, y, livery["trim"])
        canvas.plot(x, y + 1, livery["trim"])

    # Tailplane, edge-on and chunky. On a T-tail it rides on top of the fin,
    # which reads at a glance even in a 15px map icon.
    plane_len = max(6, root - 3)
    if spec.t_tail:
        # Sits across the fin plateau with a short overhang either side, so it
        # reads as mounted on the fin rather than hovering above it.
        plane_y = top_y
        plateau_end = tail + int(round(root * 0.56))
        for x in range(tail - 3, plateau_end + 4):
            canvas.plot(x, plane_y, livery["light"])
            canvas.plot(x, plane_y + 1, livery["base"])
            canvas.plot(x, plane_y + 2, livery["dark"])
    else:
        for x in range(tail + 1, tail + plane_len):
            base_y = body_top + int(round(style.rake))
            canvas.plot(x, base_y + 1, livery["light"])
            canvas.plot(x, base_y + 2, livery["base"])
            canvas.plot(x, base_y + 3, livery["dark"])


def _side_glass(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """A wrapped windscreen at the very front and a row of chunky portholes.

    The screen hugs the nose curve rather than sitting back on the flank as a
    rectangle — set back it reads as one more window and leaves a long blank
    snout, which is what made the first pass look like a bus.
    """
    style: SideStyle = ctx["style"]
    nose, tail = ctx["nose"], ctx["tail"]
    screen_back = nose - int(round(style.body_length * 0.30))
    screen_front = nose - int(round(style.body_length * 0.05))
    span = max(1, screen_front - screen_back)
    tall = max(4, int(round(style.body_height * 0.42)))

    for x in range(screen_back, screen_front + 1):
        run = (x - screen_back) / float(span)
        top, bottom = _station(ctx, x)
        # Follows the roof down over the nose, shrinking as it wraps forward.
        y0 = top + 2
        rows = max(2, int(round(tall * (1.0 - run * 0.62))))
        rows = min(rows, max(2, bottom - y0 - 2))
        for dy in range(rows):
            if dy == 0:
                colour = "glass_light"
            elif dy == rows - 1 and run < 0.5:
                colour = "metal_dark"      # lower frame, only where it is upright
            else:
                colour = "glass"
            canvas.plot(x, y0 + dy, colour)
    # Windscreen post at the back edge, which reads as a cockpit frame.
    post_top, _ = _station(ctx, screen_back)
    canvas.vline(screen_back - 1, post_top + 2, post_top + 2 + tall, "metal_dark")

    size = style.window_size
    y = ctx["body_top"] + max(3, int(round(style.body_height * 0.32)))
    start = screen_back - 4
    step = size + max(2, size // 2)
    for i in range(style.windows):
        x = start - i * step
        if x - size <= tail + max(5, style.fin_root // 2):
            break
        canvas.rect(x - size + 1, y, size - 1, size - 2, "glass")
        canvas.hline(x - size + 1, x - 1, y, "glass_light")


def _side_engines(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    style: SideStyle = ctx["style"]
    nose = ctx["nose"]
    if spec.wing_engines:
        leading = nose - int(round(style.body_length * style.wing_x))
        chord = style.wing_chord
        # The nacelle hangs clear of the fuselage and reaches forward of the
        # wing, so its propeller turns against the background. Sitting flush on
        # the wing line the prop is drawn straight over the body and vanishes.
        wing_thickness = max(3, style.body_height // 6)
        centre = (ctx["body_top"] - wing_thickness // 2 if spec.high_wing
                  else ctx["belly"] - wing_thickness // 2 - 1)
        half = max(3, style.body_height // 7)
        back = leading - int(round(chord * 0.18))
        front = leading + int(round(chord * 0.50))
        for x in range(back, front + 1):
            run = (front - x) / float(max(1, front - back))
            rows = half if run > 0.16 else max(1, half - 1)     # rounded front
            for dy in range(-rows, rows + 1):
                canvas.plot(x, centre + dy,
                            _shade(dy, rows, "metal_light", "metal", "metal_dark"))
        _side_prop(canvas, front + 3, centre, max(6, int(round(style.prop_radius * 0.70))))
    else:
        # Nose spinner sitting on the round cowl.
        top, bottom = _station(ctx, nose)
        centre = (top + bottom) // 2
        for x in range(nose - 3, nose + 1):
            t, b = _station(ctx, x)
            for y in range(t, b + 1):
                offset = y - (t + b) // 2
                canvas.plot(x, y, _shade(offset, max(1, (b - t) // 2),
                                         "metal_light", "metal", "metal_dark"))
        _side_prop(canvas, nose + 2, centre, style.prop_radius)


def _side_prop(canvas: Canvas, x: int, centre_y: int, radius: int) -> None:
    """A big chunky blade with a bright spinner.

    Blade and hub scale with the radius — a fixed one-pixel blade simply
    disappears on a 320px airframe.
    """
    blade = max(3, radius // 4)
    hub = max(3, radius // 3)
    for dy in range(-radius, radius + 1):
        t = abs(dy) / float(max(1, radius))
        # Tapers toward the tips so it reads as a blade, not a bar.
        width = blade if t < 0.55 else max(1, blade - 1)
        for dx in range(width):
            canvas.plot(x - dx, centre_y + dy, "metal_light" if dy < 0 else "metal_dark")
    # Spinner: a solid cone at the hub, which is what makes the blade read as a
    # propeller rather than as a bar drawn across the nose.
    canvas.ellipse(x - blade // 2, centre_y, hub * 0.85, hub, "metal")
    canvas.ellipse(x - blade // 2 - 1, centre_y - hub // 3, hub * 0.45, hub * 0.45, "metal_light")
    canvas.ellipse(x - blade // 2, centre_y + hub // 2, hub * 0.5, hub * 0.4, "metal_dark")


def _side_gear(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """Short fat legs and big fat wheels: toy running gear, not scale gear."""
    style: SideStyle = ctx["style"]
    nose, tail = ctx["nose"], ctx["tail"]
    baseline = ctx["baseline"]
    main_x = nose - int(round(style.body_length * (style.wing_x + 0.08)))
    _leg(canvas, main_x, _underside(canvas, main_x, ctx["belly"]), baseline, style.wheel_radius)
    if spec.gear == "taildragger":
        tail_x = tail + max(3, style.fin_root // 3)
        _leg(canvas, tail_x, _underside(canvas, tail_x, ctx["belly"]),
             baseline - style.wheel_radius, max(2, style.wheel_radius - 2))
    else:
        nose_x = nose - int(round(style.body_length * 0.14))
        _leg(canvas, nose_x, _underside(canvas, nose_x, ctx["belly"]), baseline,
             max(2, style.wheel_radius - 1))


def _underside(canvas: Canvas, x: int, fallback: int) -> int:
    for y in range(canvas.height - 1, -1, -1):
        if canvas.is_opaque(x, y):
            return y
    return fallback


def _leg(canvas: Canvas, x: int, top: int, ground: int, radius: int) -> None:
    centre_y = ground - radius
    canvas.rect(x - 1, top, 3, max(1, centre_y - top), "metal_dark")
    canvas.disc(x, centre_y, radius + 0.4, "asphalt_dark")
    canvas.disc(x, centre_y, max(1.0, radius - 1.6), "metal_dark")
    canvas.plot(x, centre_y, "metal_light")


# ---------------------------------------------------------------------------
# Rotation frames
# ---------------------------------------------------------------------------

ROTATION_FRAMES = 16
## The map icon is a separate, much smaller sprite. The 48 px airport sprite
## would cover a quarter of the United States at world zoom, and simply scaling
## it down would resample it — so the map gets its own drawing at icon scale
## (docs/WORLD_MAP_AND_ZOOM.md, "Aircraft rendering by zoom").
MAP_ICON_SIZE = 15


def _map_icon_points(spec: AircraftSpec) -> list[tuple[float, float, str]]:
    """The map aircraft as points in (along, across) aircraft space.

    Kept as coordinates rather than a bitmap so each heading can be drawn
    natively from rotated coordinates. Rotating a 15 px bitmap turns it into a
    pinwheel; rotating the coordinates and re-plotting stays crisp.

    At this size only four things can read: nose direction, wing planform,
    single versus twin, and the airline colour.
    """
    livery = _livery(spec.livery)
    big = spec.span_m >= 14.0
    half_span = 5 if big else 4
    nose = 6 if big else 5
    points: list[tuple[float, float, str]] = []

    for along in range(-5, nose + 1):
        points.append((along, 0.0, livery["light"]))
    # Wing: two rows of chord so the planform is unmistakable.
    for across in range(-half_span, half_span + 1):
        points.append((1.0, across, livery["base"]))
        if abs(across) < half_span:
            points.append((2.0, across, livery["light"]))
    # Tailplane.
    for across in range(-2, 3):
        points.append((-4.0, across, livery["base"]))
    if spec.wing_engines:
        for across in (-3, 3):
            points.append((2.0, across, "metal"))
            points.append((3.0, across, "metal_dark"))
    else:
        for across in (-2, -1, 1, 2):
            points.append((float(nose), across, "metal"))
    points.append((float(nose), 0.0, "metal_light"))
    points.append((-1.0, 0.0, livery["trim"]))
    return points


def build_map_icon(spec: AircraftSpec, heading_index: int = 0) -> Canvas:
    """One heading of the map aircraft, drawn natively at that angle."""
    canvas = Canvas(MAP_ICON_SIZE, MAP_ICON_SIZE)
    centre = MAP_ICON_SIZE // 2
    angle = heading_index * (2.0 * math.pi / ROTATION_FRAMES)
    fx, fy = math.cos(angle), math.sin(angle)
    for along, across, colour in _map_icon_points(spec):
        x = centre + along * fx - across * fy
        y = centre + along * fy + across * fx
        canvas.plot(int(round(x)), int(round(y)), colour)
    canvas.outline()
    return canvas


def build_map_rotation_strip(spec: AircraftSpec) -> Canvas:
    """All headings of the map icon, each drawn natively rather than rotated."""
    strip = Canvas(MAP_ICON_SIZE * ROTATION_FRAMES, MAP_ICON_SIZE)
    for index in range(ROTATION_FRAMES):
        strip.blit(build_map_icon(spec, index), index * MAP_ICON_SIZE, 0)
    return strip


def build_rotation_strip(spec: AircraftSpec) -> Canvas:
    """A horizontal strip of pre-rotated top views, one per heading.

    Pixel art must not be rotated at runtime: an arbitrary angle resamples the
    sprite and destroys the hard edges the whole style depends on. Instead the
    engine picks the nearest of these frames, which is how sprite-based games
    have always handled directional art.

    Frame 0 points east (+x), matching the source sprite, and frames advance
    clockwise in screen space.
    """
    from PIL import Image

    source = build_top(spec).to_image()
    size = spec.canvas_top
    strip = Canvas(size * ROTATION_FRAMES, size)
    for index in range(ROTATION_FRAMES):
        degrees = -index * (360.0 / ROTATION_FRAMES)
        # PIL rotates counter-clockwise; negating gives clockwise screen order.
        rotated = source.rotate(degrees, resample=Image.NEAREST, expand=False)
        frame = Canvas(size, size)
        frame.data[:] = _to_rgba(rotated)
        _harden(frame)
        strip.blit(frame, index * size, 0)
    return strip


def _to_rgba(image) -> "object":
    import numpy as np
    return np.array(image.convert("RGBA"), dtype=np.uint8)


def _harden(canvas: Canvas) -> None:
    """Rotation can leave stray semi-transparent pixels at the seams; the style
    guide allows only alpha 0 or 255, so they are snapped one way or the other."""
    alpha = canvas.data[:, :, 3]
    canvas.data[alpha < 128] = (0, 0, 0, 0)
    canvas.data[alpha >= 128, 3] = 255
