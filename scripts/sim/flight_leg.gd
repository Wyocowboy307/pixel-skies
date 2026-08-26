class_name FlightLeg
extends RefCounted
## A persistent flight record. The moving sprite is only one presentation of
## this state (docs/FLIGHT_SYSTEM.md).
##
## Every phase boundary is a timestamp, so progress is reconstructed identically
## whether the game stayed open, was minimised, or was closed for a week.

enum Phase {
    PARKED, LOADING, PUSHBACK, TAXI_OUT, TAKEOFF_ROLL, CLIMB,
    ENROUTE, APPROACH, LANDING_ROLL, TAXI_IN, UNLOADING, COMPLETE,
}

const PHASE_NAMES := {
    Phase.PARKED: "Parked", Phase.LOADING: "Loading", Phase.PUSHBACK: "Push and start",
    Phase.TAXI_OUT: "Taxiing out", Phase.TAKEOFF_ROLL: "Takeoff roll", Phase.CLIMB: "Climbing",
    Phase.ENROUTE: "En route", Phase.APPROACH: "On approach", Phase.LANDING_ROLL: "Landing",
    Phase.TAXI_IN: "Taxiing in", Phase.UNLOADING: "Unloading", Phase.COMPLETE: "Complete",
}

var id := ""
var aircraft_id := ""
var origin_id := ""
var destination_id := ""
var payload_ids: Array[String] = []
var distance_nm := 0.0
var operating_cost := 0
var expected_revenue := 0
## Ordered phase boundaries; entry i is when phase i ends.
var phase_ends: Dictionary = {}
var departure_unix := 0.0
var arrival_unix := 0.0
## Idempotent settlement guard: payout happens exactly once, ever.
var settled := false

## Phases in the order they occur.
static func phase_order() -> Array:
    return [
        Phase.LOADING, Phase.PUSHBACK, Phase.TAXI_OUT, Phase.TAKEOFF_ROLL, Phase.CLIMB,
        Phase.ENROUTE, Phase.APPROACH, Phase.LANDING_ROLL, Phase.TAXI_IN, Phase.UNLOADING,
    ]

func phase_at(now_unix: float) -> Phase:
    if now_unix >= arrival_unix:
        return Phase.COMPLETE
    for phase: Phase in phase_order():
        if now_unix < float(phase_ends.get(phase, 0.0)):
            return phase
    return Phase.COMPLETE

func phase_name(now_unix: float) -> String:
    return String(PHASE_NAMES.get(phase_at(now_unix), "Unknown"))

## Progress through the whole leg, 0..1.
func progress(now_unix: float) -> float:
    if arrival_unix <= departure_unix:
        return 1.0
    return clampf((now_unix - departure_unix) / (arrival_unix - departure_unix), 0.0, 1.0)

## Progress through the airborne portion only, which is what the world map
## timeline represents.
func enroute_progress(now_unix: float) -> float:
    var start: float = float(phase_ends.get(Phase.CLIMB, departure_unix))
    var end: float = float(phase_ends.get(Phase.ENROUTE, arrival_unix))
    if end <= start:
        return clampf(progress(now_unix), 0.0, 1.0)
    return clampf((now_unix - start) / (end - start), 0.0, 1.0)

func is_airborne(now_unix: float) -> bool:
    var phase: Phase = phase_at(now_unix)
    return phase >= Phase.TAKEOFF_ROLL and phase <= Phase.LANDING_ROLL

func is_complete(now_unix: float) -> bool:
    return now_unix >= arrival_unix

func seconds_remaining(now_unix: float) -> float:
    return maxf(0.0, arrival_unix - now_unix)

func to_dict() -> Dictionary:
    var ends: Dictionary = {}
    for phase: Variant in phase_ends:
        ends[str(int(phase))] = phase_ends[phase]
    return {
        "id": id, "aircraft_id": aircraft_id, "origin_id": origin_id,
        "destination_id": destination_id, "payload_ids": payload_ids.duplicate(),
        "distance_nm": distance_nm, "operating_cost": operating_cost,
        "expected_revenue": expected_revenue, "phase_ends": ends,
        "departure_unix": departure_unix, "arrival_unix": arrival_unix,
        "settled": settled,
    }

static func from_dict(data: Dictionary) -> FlightLeg:
    var leg := FlightLeg.new()
    leg.id = String(data.get("id", ""))
    leg.aircraft_id = String(data.get("aircraft_id", ""))
    leg.origin_id = String(data.get("origin_id", ""))
    leg.destination_id = String(data.get("destination_id", ""))
    leg.distance_nm = float(data.get("distance_nm", 0.0))
    leg.operating_cost = int(data.get("operating_cost", 0))
    leg.expected_revenue = int(data.get("expected_revenue", 0))
    leg.departure_unix = float(data.get("departure_unix", 0.0))
    leg.arrival_unix = float(data.get("arrival_unix", 0.0))
    leg.settled = bool(data.get("settled", false))
    var payload: Array[String] = []
    for entry: Variant in data.get("payload_ids", []):
        payload.append(String(entry))
    leg.payload_ids = payload
    var ends: Dictionary = {}
    for key: Variant in data.get("phase_ends", {}):
        ends[int(String(key))] = float((data["phase_ends"] as Dictionary)[key])
    leg.phase_ends = ends
    return leg
