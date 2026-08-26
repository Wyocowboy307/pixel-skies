class_name GroundPath
extends RefCounted
## Sampling along an authored polyline of taxi waypoints.
##
## Ground movement is authored, not pathfound (docs/TECH_ARCHITECTURE.md,
## "Airport movement"). This turns "how far along are you" into a position and a
## heading, which is all the presentation layer needs to move an aircraft from a
## stand to a runway without it teleporting between waypoints.
##
## Pure geometry: no scene, no state, so it is directly testable.

## Total length of a polyline.
static func length_of(points: PackedVector2Array) -> float:
    var total := 0.0
    for i in range(points.size() - 1):
        total += points[i].distance_to(points[i + 1])
    return total

## Position at `t` in 0..1 along the polyline, measured by distance so an
## aircraft moves at a constant speed rather than jumping between waypoints.
static func sample(points: PackedVector2Array, t: float) -> Vector2:
    if points.is_empty():
        return Vector2.ZERO
    if points.size() == 1:
        return points[0]
    var target: float = clampf(t, 0.0, 1.0) * length_of(points)
    var travelled := 0.0
    for i in range(points.size() - 1):
        var segment: float = points[i].distance_to(points[i + 1])
        if segment <= 0.0:
            continue
        if travelled + segment >= target:
            return points[i].lerp(points[i + 1], (target - travelled) / segment)
        travelled += segment
    return points[points.size() - 1]

## Direction of travel at `t`, in radians. Looks a little ahead so an aircraft
## begins turning into a corner rather than snapping at the waypoint.
static func heading_at(points: PackedVector2Array, t: float, lookahead: float = 0.02) -> float:
    if points.size() < 2:
        return 0.0
    var here: Vector2 = sample(points, t)
    var ahead: Vector2 = sample(points, minf(1.0, t + lookahead))
    if here.distance_to(ahead) < 0.001:
        # At the very end, take the direction of the final segment instead.
        var behind: Vector2 = sample(points, maxf(0.0, t - lookahead))
        return (here - behind).angle() if behind.distance_to(here) > 0.001 else 0.0
    return (ahead - here).angle()

static func to_points(raw: Variant) -> PackedVector2Array:
    var out: PackedVector2Array = []
    for entry: Variant in (raw as Array):
        var pair: Array = entry
        if pair.size() >= 2:
            out.append(Vector2(float(pair[0]), float(pair[1])))
    return out
