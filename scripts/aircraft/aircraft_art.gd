class_name AircraftArt
extends RefCounted
## Procedural top-down aircraft drawing.
##
## Stands in for the generated sprites named by `art_top` in data/aircraft.json
## so the flight, airport and map systems can be built and reviewed before Phase
## A art exists (docs/ART_PIPELINE.md). It follows the same readability rules the
## sprites must meet: obvious nose direction, obvious wing planform, prop versus
## jet legible, airline colour visible, no rivet-level noise.
##
## Shapes are built in aircraft-local (along, across) units — `along` is toward
## the nose, `across` is the starboard wing — then mapped into world space once.
## That keeps the geometry readable and makes every proportion a fraction of the
## airframe's length.

const LIVERIES := {
    "house": Color("#e0d4b4"),
    "sunrise": Color("#e79a52"),
    "alpine": Color("#8fc7d6"),
}

const OUTLINE := Color("#12181f")
const WINDOW := Color("#2f4356")
const NACELLE := Color("#3f4a54")
const NACELLE_LIT := Color("#5d6a74")
const PROP_BLUR := Color("#cfd8de", 0.28)
const PROP_BLADE := Color("#9aa5ad")
const SHADOW := Color("#0d141a", 0.28)

static func livery_color(name: String) -> Color:
    return LIVERIES.get(name, LIVERIES["house"])

## Draws an aircraft centred at `at` with its nose along `heading_radians`
## (0 = east). `spin` is a running propeller phase; pass a negative value for a
## stopped engine.
static func draw_top(canvas: CanvasItem, at: Vector2, heading_radians: float,
        family: Dictionary, scale: float, livery: Color, spin: float = -1.0) -> void:
    var shape: Dictionary = family.get("silhouette", {})
    var length: float = float(shape.get("length", 36)) * scale
    var span: float = float(shape.get("span", 48)) * scale
    var tail_span: float = float(shape.get("tail_span", 18)) * scale
    var engines: int = int(shape.get("engines", 1))
    var nose_mounted: bool = String(shape.get("engine_mount", "nose")) == "nose" or engines <= 1
    var high_wing: bool = String(shape.get("wing", "high")) == "high"
    var wing_along: float = (0.5 - float(shape.get("wing_position", 0.33))) * length

    var forward := Vector2(cos(heading_radians), sin(heading_radians))
    var side := Vector2(-forward.y, forward.x)

    var fuselage: PackedVector2Array = _fuselage_points(length)
    var wing: PackedVector2Array = _wing_points(length, span, wing_along)
    var tail: PackedVector2Array = _wing_points(length * 0.42, tail_span, -length * 0.44)
    var fin: PackedVector2Array = _fin_points(length)

    # Ground shadow, offset down-right for the upper-left light direction.
    var drop: Vector2 = Vector2(2.0, 3.0) * maxf(0.5, scale * 0.6)
    _fill(canvas, wing, at + drop, forward, side, SHADOW)
    _fill(canvas, fuselage, at + drop, forward, side, SHADOW)

    # Low wings pass under the fuselage, high wings over it: the overlap order is
    # what tells the two apart from directly above.
    if not high_wing:
        _fill(canvas, wing, at, forward, side, livery.darkened(0.16))
        _stroke(canvas, wing, at, forward, side, OUTLINE)
    _fill(canvas, tail, at, forward, side, livery.darkened(0.10))
    _stroke(canvas, tail, at, forward, side, OUTLINE)
    _fill(canvas, fin, at, forward, side, livery.darkened(0.34))
    _fill(canvas, fuselage, at, forward, side, livery)
    _stroke(canvas, fuselage, at, forward, side, OUTLINE)
    if high_wing:
        _fill(canvas, wing, at, forward, side, livery)
        _stroke(canvas, wing, at, forward, side, OUTLINE)

    _cockpit(canvas, at, forward, side, length)
    _engines(canvas, at, forward, side, length, span, wing_along, engines, nose_mounted, scale, spin)

    # Airline stripe along the spine keeps the operator readable at map scale.
    if scale >= 0.5:
        canvas.draw_line(
            _point(at, forward, side, Vector2(length * 0.16, 0.0)),
            _point(at, forward, side, Vector2(-length * 0.38, 0.0)),
            livery.darkened(0.42), maxf(1.0, length * 0.035))

# ---------------------------------------------------------------------------
# Local-space shapes. Vector2 is (along, across).
# ---------------------------------------------------------------------------

## Tapered hull: widest a quarter back from the nose, narrowing to the tail.
static func _fuselage_points(length: float) -> PackedVector2Array:
    var half: float = length * 0.115
    return PackedVector2Array([
        Vector2(length * 0.50, 0.0),
        Vector2(length * 0.40, half * 0.52),
        Vector2(length * 0.24, half),
        Vector2(-length * 0.14, half),
        Vector2(-length * 0.38, half * 0.52),
        Vector2(-length * 0.50, half * 0.26),
        Vector2(-length * 0.50, -half * 0.26),
        Vector2(-length * 0.38, -half * 0.52),
        Vector2(-length * 0.14, -half),
        Vector2(length * 0.24, -half),
        Vector2(length * 0.40, -half * 0.52),
    ])

## One polygon covering both wings and the centre section, walked around its
## perimeter so it stays a simple (non-self-intersecting) shape.
static func _wing_points(length: float, span: float, along: float) -> PackedVector2Array:
    var root_chord: float = length * 0.27
    var tip_chord: float = root_chord * 0.66
    var sweep: float = length * 0.05
    var tip: float = span * 0.5
    var root: float = length * 0.10
    var le_root: float = along + root_chord * 0.5
    var te_root: float = along - root_chord * 0.5
    var le_tip: float = along + tip_chord * 0.5 - sweep
    var te_tip: float = along - tip_chord * 0.5 - sweep
    return PackedVector2Array([
        Vector2(le_tip, tip), Vector2(te_tip, tip),
        Vector2(te_root, root), Vector2(te_root, -root),
        Vector2(te_tip, -tip), Vector2(le_tip, -tip),
        Vector2(le_root, -root), Vector2(le_root, root),
    ])

## Seen from above the fin is nearly edge-on, so it reads as a narrow wedge
## running back along the centreline.
static func _fin_points(length: float) -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(-length * 0.18, 0.0),
        Vector2(-length * 0.52, length * 0.055),
        Vector2(-length * 0.52, -length * 0.055),
    ])

# ---------------------------------------------------------------------------
# Details
# ---------------------------------------------------------------------------

static func _cockpit(canvas: CanvasItem, at: Vector2, forward: Vector2, side: Vector2,
        length: float) -> void:
    var half: float = length * 0.115
    var glass := PackedVector2Array([
        Vector2(length * 0.33, half * 0.42),
        Vector2(length * 0.18, half * 0.72),
        Vector2(length * 0.18, -half * 0.72),
        Vector2(length * 0.33, -half * 0.42),
    ])
    _fill(canvas, glass, at, forward, side, WINDOW)

static func _engines(canvas: CanvasItem, at: Vector2, forward: Vector2, side: Vector2,
        length: float, span: float, wing_along: float, engines: int,
        nose_mounted: bool, scale: float, spin: float) -> void:
    var mounts: Array[Vector2] = []
    var prop_radius: float = 0.0
    if nose_mounted:
        mounts.append(Vector2(length * 0.50, 0.0))
        prop_radius = span * 0.19
    else:
        var offset: float = span * 0.27
        var forward_of_wing: float = wing_along + length * 0.20
        mounts.append(Vector2(forward_of_wing, offset))
        mounts.append(Vector2(forward_of_wing, -offset))
        prop_radius = span * 0.15

    for mount: Vector2 in mounts:
        var centre: Vector2 = _point(at, forward, side, mount)
        if not nose_mounted:
            # Nacelle body, so a twin reads as a twin even with the prop stopped.
            var nacelle := PackedVector2Array([
                Vector2(mount.x, mount.y + length * 0.05),
                Vector2(mount.x - length * 0.30, mount.y + length * 0.045),
                Vector2(mount.x - length * 0.30, mount.y - length * 0.045),
                Vector2(mount.x, mount.y - length * 0.05),
            ])
            _fill(canvas, nacelle, at, forward, side, NACELLE)
            _stroke(canvas, nacelle, at, forward, side, OUTLINE)
        canvas.draw_circle(centre, maxf(1.5, length * 0.055), NACELLE)
        canvas.draw_circle(centre, maxf(1.0, length * 0.03), NACELLE_LIT)

        if spin >= 0.0:
            canvas.draw_circle(centre, prop_radius, PROP_BLUR)
            var blade: Vector2 = Vector2(cos(spin), sin(spin)).rotated(forward.angle()) * prop_radius
            canvas.draw_line(centre - blade, centre + blade, Color("#e6edf1", 0.45), maxf(1.0, scale))
        elif scale >= 0.4:
            # Stopped: two crisp blades across the hub read as "prop", not "jet".
            var across: Vector2 = side * prop_radius
            var along: Vector2 = forward * prop_radius * 0.28
            canvas.draw_line(centre - across, centre + across, PROP_BLADE, maxf(1.0, scale * 1.2))
            canvas.draw_line(centre - along, centre + along, PROP_BLADE, maxf(1.0, scale))

# ---------------------------------------------------------------------------
# Local -> world helpers
# ---------------------------------------------------------------------------

static func _point(at: Vector2, forward: Vector2, side: Vector2, local: Vector2) -> Vector2:
    return at + forward * local.x + side * local.y

static func _map(points: PackedVector2Array, at: Vector2, forward: Vector2, side: Vector2) -> PackedVector2Array:
    var out: PackedVector2Array = []
    for local: Vector2 in points:
        out.append(_point(at, forward, side, local))
    return out

static func _fill(canvas: CanvasItem, points: PackedVector2Array, at: Vector2,
        forward: Vector2, side: Vector2, color: Color) -> void:
    canvas.draw_colored_polygon(_map(points, at, forward, side), color)

static func _stroke(canvas: CanvasItem, points: PackedVector2Array, at: Vector2,
        forward: Vector2, side: Vector2, color: Color) -> void:
    var mapped: PackedVector2Array = _map(points, at, forward, side)
    mapped.append(mapped[0])
    canvas.draw_polyline(mapped, color, 1.0)
