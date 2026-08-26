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
        canvas_top=96, canvas_side=(240, 88),
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

def build_side(spec: AircraftSpec) -> Canvas:
    width, height = spec.canvas_side
    canvas = Canvas(width, height)
    livery = _livery(spec.livery)

    total_height_m = spec.gear_height_m + spec.fuselage_height_m + spec.fin_height_m
    ppm = min((width - 8) / spec.length_m, (height - 6) / total_height_m)

    length = round(spec.length_m * ppm)
    nose = (width + length) // 2 - 1
    tail = nose - length
    # A shared baseline means every aircraft lines up in the detail view.
    baseline = height - 3
    belly = baseline - round(spec.gear_height_m * ppm)
    body_h = max(4, round(spec.fuselage_height_m * ppm))
    body_top = belly - body_h

    ctx = dict(ppm=ppm, nose=nose, tail=tail, length=length, baseline=baseline,
               belly=belly, body_top=body_top, body_h=body_h, livery=livery)

    _side_tail(canvas, spec, ctx)
    _side_fuselage(canvas, spec, ctx)
    _side_wing(canvas, spec, ctx)
    _side_engines(canvas, spec, ctx)
    _side_glass(canvas, spec, ctx)
    _side_gear(canvas, spec, ctx)
    canvas.outline()
    return canvas


def _side_fuselage(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    livery = ctx["livery"]
    nose, tail, length = ctx["nose"], ctx["tail"], ctx["length"]
    body_top, belly, body_h = ctx["body_top"], ctx["belly"], ctx["body_h"]
    nose_run = max(3, int(length * 0.14))
    boom_start = int(length * 0.58)
    for x in range(tail, nose + 1):
        back = nose - x
        if back < nose_run:
            t = back / nose_run
            top = body_top + round((1.0 - t) * body_h * 0.42)
            bottom = belly - round((1.0 - t) * body_h * 0.26)
        elif back > boom_start:
            run = (back - boom_start) / max(1, length - boom_start)
            top = body_top + round(run * body_h * 0.34)
            # The underside sweeps up toward the tail, which is what gives an
            # aeroplane its recognisable side profile.
            bottom = belly - round(run * body_h * 0.62)
        else:
            top, bottom = body_top, belly
        if bottom < top:
            bottom = top
        for y in range(top, bottom + 1):
            offset = y - (top + bottom) // 2
            half = max(1, (bottom - top) // 2)
            canvas.plot(x, y, _shade(offset, half, livery["light"], livery["base"], livery["dark"]))


def _side_wing(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    """Edge-on, a wing is a thin tapered blade — its height on the fuselage is
    what tells a high wing from a low one."""
    livery = ctx["livery"]
    ppm, nose = ctx["ppm"], ctx["nose"]
    chord = max(4, round(spec.wing_chord_m * ppm))
    leading = nose - round(spec.length_m * spec.wing_x_frac * ppm)
    thickness = max(2, round(spec.wing_chord_m * ppm * 0.11))
    # A high wing is mounted on top of the fuselage, so its blade must be drawn
    # above the roof line. Drawn at the roof line it is simply invisible, which
    # is what made the first pass read as a boat hull.
    y = ctx["body_top"] - thickness + 1 if spec.high_wing else ctx["belly"] - thickness - 1
    for x in range(leading - chord, leading + 1):
        run = (leading - x) / max(1, chord)
        t = thickness if run < 0.55 else max(1, thickness - 1)
        for dy in range(t):
            canvas.plot(x, y + dy, livery["light"] if dy == 0 else livery["base"])
    if spec.struts and spec.high_wing:
        canvas.line(leading - chord + 1, y + thickness,
                    leading - chord - max(3, chord // 2), ctx["belly"] - 2, "metal_dark")


def _side_tail(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    livery = ctx["livery"]
    ppm, tail, body_top = ctx["ppm"], ctx["tail"], ctx["body_top"]
    fin_h = max(4, round(spec.fin_height_m * ppm))
    root = max(4, round(spec.tail_chord_m * ppm * 1.35))
    top_y = body_top - fin_h
    # Swept fin: leading edge rakes back, trailing edge is vertical at the tail.
    for x in range(tail, tail + root + 1):
        run = (x - tail) / max(1, root)
        y_top = round(top_y + (1.0 - run) * fin_h * 0.0 + run * 0.0)
        y_top = top_y if run > 0.45 else round(body_top - fin_h * (run / 0.45))
        for y in range(y_top, body_top + 1):
            canvas.plot(x, y, livery["light"] if y <= y_top + 1 else livery["base"])
    # Tailplane, edge-on, at the base of the fin.
    plane_len = max(3, round(spec.tail_chord_m * ppm * 1.9))
    for x in range(tail + 1, tail + plane_len):
        canvas.plot(x, body_top + 1, livery["base"])
        canvas.plot(x, body_top + 2, livery["dark"])
    # Trim flash on the fin: the airline's identity mark.
    for x in range(tail + 1, tail + root):
        run = (x - tail) / max(1, root)
        y = round(top_y + fin_h * 0.30 + run * fin_h * 0.30)
        canvas.plot(x, y, livery["trim"])


def _side_engines(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    ppm, nose = ctx["ppm"], ctx["nose"]
    prop_half = max(4, round(spec.prop_diameter_m * ppm * 0.5))
    if spec.wing_engines:
        chord = max(4, round(spec.wing_chord_m * ppm))
        leading = nose - round(spec.length_m * spec.wing_x_frac * ppm)
        centre = (ctx["body_top"] if spec.high_wing else ctx["belly"] - 2)
        centre += 1 if spec.high_wing else -1
        half = max(1, round(spec.fuselage_height_m * ppm * 0.15))
        front = leading + round(chord * 0.55)
        for x in range(leading - round(chord * 0.7), front + 1):
            for dy in range(-half, half + 1):
                canvas.plot(x, centre + dy,
                            _shade(dy, half, "metal_light", "metal", "metal_dark"))
        _side_prop(canvas, front + 2, centre, prop_half)
    else:
        cowl = max(3, round(ctx["length"] * 0.11))
        for x in range(nose - cowl, nose + 1):
            back = nose - x
            t = back / cowl
            top = ctx["body_top"] + round((1.0 - t) * ctx["body_h"] * 0.28)
            bottom = ctx["belly"] - round((1.0 - t) * ctx["body_h"] * 0.28)
            for y in range(top, bottom + 1):
                offset = y - (top + bottom) // 2
                canvas.plot(x, y, _shade(offset, max(1, (bottom - top) // 2),
                                         "metal_light", "metal", "metal_dark"))
        _side_prop(canvas, nose + 2, (ctx["body_top"] + ctx["belly"]) // 2, prop_half)


def _side_prop(canvas: Canvas, x: int, centre_y: int, half: int) -> None:
    canvas.vline(x, centre_y - half, centre_y + half, "metal_dark")
    canvas.plot(x, centre_y, "metal_light")


def _side_glass(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    nose, tail, length = ctx["nose"], ctx["tail"], ctx["length"]
    body_top = ctx["body_top"]
    # Raked windscreen.
    screen = nose - max(3, int(length * 0.13))
    for i in range(max(2, int(length * 0.045))):
        canvas.vline(screen - i, body_top + 2, body_top + 3 + i // 2, "glass_light")
    # Cabin windows, evenly spaced back along the fuselage.
    y = body_top + max(2, ctx["body_h"] // 4)
    start = screen - max(4, int(length * 0.07))
    step = max(3, int(length * 0.055))
    size = max(2, int(length * 0.022))
    for i in range(spec.cabin_windows):
        x = start - i * step
        if x - size <= tail + max(4, int(length * 0.10)):
            break
        canvas.rect(x - size, y, size, size, "glass")
        canvas.hline(x - size, x - 1, y, "glass_light")


def _side_gear(canvas: Canvas, spec: AircraftSpec, ctx: dict) -> None:
    nose, tail, length = ctx["nose"], ctx["tail"], ctx["length"]
    belly, baseline, ppm = ctx["belly"], ctx["baseline"], ctx["ppm"]
    wheel = max(1.5, spec.gear_height_m * ppm * 0.34)
    main_x = nose - round(length * (spec.wing_x_frac + 0.10))
    _leg(canvas, main_x, _underside(canvas, main_x, belly), baseline, wheel)
    if spec.gear == "taildragger":
        tail_x = tail + max(3, round(length * 0.06))
        # The tail wheel hangs off the tail cone, which has already swept up, so
        # its leg must start at the actual underside at that station.
        _leg(canvas, tail_x, _underside(canvas, tail_x, belly),
             baseline - max(1, int(wheel)), wheel * 0.6)
    else:
        nose_x = nose - round(length * 0.13)
        _leg(canvas, nose_x, _underside(canvas, nose_x, belly), baseline, wheel * 0.85)


def _underside(canvas: Canvas, x: int, fallback: int) -> int:
    """Lowest opaque pixel of the airframe at station `x`."""
    for y in range(canvas.height - 1, -1, -1):
        if canvas.is_opaque(x, y):
            return y
    return fallback


def _leg(canvas: Canvas, x: int, top: int, ground: int, wheel: float) -> None:
    radius = max(1.0, wheel)
    canvas.vline(x, top, round(ground - radius), "metal_dark")
    canvas.disc(x, ground - radius, radius, "asphalt_dark")
    canvas.plot(x, round(ground - radius), "metal")
