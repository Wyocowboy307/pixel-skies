class_name FlightGround
extends RefCounted
## Where an aircraft physically is on an airfield, derived from its flight's
## phase timestamps.
##
## Presentation only. It reads the leg; it never writes to it. Duration, payout
## and settlement are entirely unaffected by anything here
## (docs/TESTING.md, "Regression rule").
##
## The aircraft never teleports: every phase hands off at the position the next
## one starts from, so a departure runs stand -> push -> taxi -> line up ->
## roll -> rotate -> climb as one continuous movement.

enum Role { NONE, DEPARTING, ARRIVING }

## Eased progress with a slow start, used for the takeoff roll so the aircraft
## visibly accelerates rather than sliding at a constant rate.
static func _accelerate(t: float) -> float:
    var x: float = clampf(t, 0.0, 1.0)
    return x * x

## Slow finish, for the landing roll.
static func _decelerate(t: float) -> float:
    var x: float = clampf(t, 0.0, 1.0)
    return 1.0 - (1.0 - x) * (1.0 - x)

static func role_for(leg: FlightLeg, airport_id: String) -> Role:
    if leg == null:
        return Role.NONE
    if leg.origin_id == airport_id:
        return Role.DEPARTING
    if leg.destination_id == airport_id:
        return Role.ARRIVING
    return Role.NONE

## Fraction through a single phase, 0..1.
static func phase_progress(leg: FlightLeg, phase: FlightLeg.Phase, now: float) -> float:
    var order: Array = FlightLeg.phase_order()
    var index: int = order.find(phase)
    if index < 0:
        return 0.0
    var ends: float = float(leg.phase_ends.get(phase, leg.departure_unix))
    var starts: float = leg.departure_unix if index == 0 \
        else float(leg.phase_ends.get(order[index - 1], leg.departure_unix))
    if ends <= starts:
        return 1.0
    return clampf((now - starts) / (ends - starts), 0.0, 1.0)

## Full visual state for an aircraft on this airfield.
##
## Returns `visible=false` when the aircraft is airborne and away, which is the
## world map's job to draw.
static func state(leg: FlightLeg, airport_id: String, layout: Dictionary,
        stand_id: String, now: float) -> Dictionary:
    var role: Role = role_for(leg, airport_id)
    var ground: Dictionary = layout.get("ground", {})
    var stands: Dictionary = ground.get("stands", {})
    var route: Dictionary = stands.get(stand_id, {})
    if role == Role.NONE or route.is_empty():
        return {"visible": false}

    var phase: FlightLeg.Phase = leg.phase_at(now)
    var t: float = phase_progress(leg, phase, now)
    var threshold: Vector2 = _vec(ground.get("threshold", [0, 0]))
    var rotate_at: Vector2 = _vec(ground.get("rotate_at", [0, 0]))
    var runway_end: Vector2 = _vec(ground.get("runway_end", [0, 0]))
    var touchdown: Vector2 = _vec(ground.get("touchdown", [0, 0]))
    var exit_at: Vector2 = _vec(ground.get("exit_at", [0, 0]))

    var pushback: PackedVector2Array = GroundPath.to_points(route.get("pushback", []))
    var taxi_out: PackedVector2Array = GroundPath.to_points(route.get("taxi_out", []))
    var taxi_in: PackedVector2Array = GroundPath.to_points(route.get("taxi_in", []))

    var result: Dictionary = {
        "visible": true, "position": Vector2.ZERO, "heading": 0.0,
        "altitude": 0.0, "engines": false, "on_ground": true, "phase": phase,
    }

    if role == Role.DEPARTING:
        match phase:
            FlightLeg.Phase.LOADING:
                result["position"] = pushback[0] if not pushback.is_empty() else Vector2.ZERO
                result["heading"] = _stand_heading(layout, stand_id)
            FlightLeg.Phase.PUSHBACK:
                # Reverses off the stand: moves backwards, still facing the terminal.
                result["position"] = GroundPath.sample(pushback, t)
                result["heading"] = _stand_heading(layout, stand_id)
                result["engines"] = t > 0.4
            FlightLeg.Phase.TAXI_OUT:
                result["position"] = GroundPath.sample(taxi_out, t)
                result["heading"] = GroundPath.heading_at(taxi_out, t)
                result["engines"] = true
            FlightLeg.Phase.TAKEOFF_ROLL:
                # Accelerating: slow off the mark, fast at rotation.
                result["position"] = threshold.lerp(rotate_at, _accelerate(t))
                result["heading"] = (rotate_at - threshold).angle()
                result["engines"] = true
            FlightLeg.Phase.CLIMB:
                result["position"] = rotate_at.lerp(runway_end, clampf(t * 1.6, 0.0, 1.0))
                result["heading"] = (runway_end - rotate_at).angle()
                result["altitude"] = clampf(t * 1.5, 0.0, 1.0)
                result["engines"] = true
                result["on_ground"] = false
                if t > 0.72:
                    result["visible"] = false      # handed off to the world map
            _:
                result["visible"] = false
        return result

    match phase:
        FlightLeg.Phase.APPROACH:
            # Comes in from beyond the threshold, descending onto it.
            var entry: Vector2 = touchdown - (exit_at - touchdown).normalized() * 260.0
            result["position"] = entry.lerp(touchdown, clampf(t, 0.0, 1.0))
            result["heading"] = (exit_at - touchdown).angle()
            result["altitude"] = clampf(1.0 - t, 0.0, 1.0)
            result["engines"] = true
            result["on_ground"] = false
            result["visible"] = t > 0.35        # only once it is near the field
        FlightLeg.Phase.LANDING_ROLL:
            result["position"] = touchdown.lerp(exit_at, _decelerate(t))
            result["heading"] = (exit_at - touchdown).angle()
            result["engines"] = true
            result["touchdown_puff"] = t < 0.12
        FlightLeg.Phase.TAXI_IN:
            result["position"] = GroundPath.sample(taxi_in, t)
            result["heading"] = GroundPath.heading_at(taxi_in, t)
            result["engines"] = t < 0.85
        FlightLeg.Phase.UNLOADING:
            result["position"] = taxi_in[taxi_in.size() - 1] if not taxi_in.is_empty() else Vector2.ZERO
            result["heading"] = _stand_heading(layout, stand_id)
        _:
            result["visible"] = false
    return result

static func _stand_heading(layout: Dictionary, stand_id: String) -> float:
    for entry: Variant in layout.get("stands", []):
        var stand: Dictionary = entry
        if String(stand.get("id", "")) == stand_id:
            return deg_to_rad(float(stand.get("heading", -90.0)))
    return -PI * 0.5

static func _vec(raw: Variant) -> Vector2:
    var array: Array = raw
    if array.size() < 2:
        return Vector2.ZERO
    return Vector2(float(array[0]), float(array[1]))
