class_name FlightService
extends RefCounted
## Dispatching, phase timing and settlement.
##
## A leg's whole timeline is written once at dispatch, as absolute timestamps.
## Progress is then a pure function of "what time is it now", which is what makes
## offline progression and save/resume correct by construction
## (docs/FLIGHT_SYSTEM.md, "Offline progression").

## Real flying hours are divided by this to get game time. Tuned so a Trailhopper
## hop to BIL is a ~14 minute errand and a Denver run is about an hour, while a
## faster aircraft is meaningfully quicker over the same leg.
const TIME_SCALE := 4.0

## Ground and transition phase durations in game seconds. Loading and unloading
## scale with the aircraft's turnaround stat; the rest are fixed presentation
## beats that give departure and arrival something to show.
const PUSHBACK_SECONDS := 12.0
const TAXI_OUT_SECONDS := 45.0
const TAKEOFF_ROLL_SECONDS := 12.0
const CLIMB_SECONDS := 25.0
const APPROACH_SECONDS := 25.0
const LANDING_ROLL_SECONDS := 12.0
const TAXI_IN_SECONDS := 40.0
const MINIMUM_ENROUTE_SECONDS := 20.0

var db: GameDB
var ids: Ids

func _init(database: GameDB, id_source: Ids) -> void:
    db = database
    ids = id_source

## First stand at `airport_id` that no parked aircraft is occupying.
##
## An arriving aircraft has to be given one, or it lands with no stand and the
## airport scene has nowhere to draw it.
func free_stand(state: AirlineState, airport_id: String) -> String:
    var layout: Dictionary = db.layout_for_airport(airport_id)
    var taken: Dictionary = {}
    for plane: AircraftInstance in state.aircraft_at(airport_id):
        if not plane.stand_id.is_empty():
            taken[plane.stand_id] = true
    for entry: Variant in layout.get("stands", []):
        var stand_id: String = String((entry as Dictionary).get("id", ""))
        if not stand_id.is_empty() and not taken.has(stand_id):
            return stand_id
    return ""

func distance_between(origin_id: String, destination_id: String) -> float:
    var a: Dictionary = db.airports.get(origin_id, {})
    var b: Dictionary = db.airports.get(destination_id, {})
    if a.is_empty() or b.is_empty():
        return 0.0
    return WorldProjection.great_circle_nm(
        float(a["lat"]), float(a["lon"]), float(b["lat"]), float(b["lon"]))

## Total gate-to-gate duration in game seconds.
func estimate_duration(family: Dictionary, distance_nm: float) -> float:
    var timeline: Dictionary = _build_timeline(family, distance_nm, 0.0)
    return float(timeline["arrival"])

func _build_timeline(family: Dictionary, distance_nm: float, start_unix: float) -> Dictionary:
    var cruise_kts: float = maxf(1.0, float(family.get("cruise_kts", 120.0)))
    var turnaround: float = float(family.get("turnaround_seconds_game", 45.0))
    var air_seconds: float = (distance_nm / cruise_kts) * 3600.0 / TIME_SCALE
    # Climb and approach are carved out of the air time rather than added to it,
    # so the quoted duration still reflects the aircraft's cruise speed.
    var enroute: float = maxf(MINIMUM_ENROUTE_SECONDS, air_seconds - CLIMB_SECONDS - APPROACH_SECONDS)

    var ends: Dictionary = {}
    var cursor: float = start_unix
    var steps: Array = [
        [FlightLeg.Phase.LOADING, turnaround],
        [FlightLeg.Phase.PUSHBACK, PUSHBACK_SECONDS],
        [FlightLeg.Phase.TAXI_OUT, TAXI_OUT_SECONDS],
        [FlightLeg.Phase.TAKEOFF_ROLL, TAKEOFF_ROLL_SECONDS],
        [FlightLeg.Phase.CLIMB, CLIMB_SECONDS],
        [FlightLeg.Phase.ENROUTE, enroute],
        [FlightLeg.Phase.APPROACH, APPROACH_SECONDS],
        [FlightLeg.Phase.LANDING_ROLL, LANDING_ROLL_SECONDS],
        [FlightLeg.Phase.TAXI_IN, TAXI_IN_SECONDS],
        [FlightLeg.Phase.UNLOADING, turnaround * 0.8],
    ]
    for step: Array in steps:
        cursor += float(step[1])
        ends[step[0]] = cursor
    return {"ends": ends, "arrival": cursor - start_unix}

## Creates exactly one flight and hands the aircraft over to it.
func dispatch(state: AirlineState, aircraft_id: String, destination_id: String,
        now_unix: float) -> FlightLeg:
    var plane: AircraftInstance = state.aircraft.get(aircraft_id, null)
    if plane == null:
        return null
    var family: Dictionary = db.aircraft.get(plane.family_id, {})
    var origin_id: String = plane.location_id
    var distance: float = distance_between(origin_id, destination_id)

    var leg := FlightLeg.new()
    leg.id = ids.next("flt")
    leg.aircraft_id = aircraft_id
    leg.origin_id = origin_id
    leg.destination_id = destination_id
    leg.payload_ids = plane.loaded_job_ids.duplicate()
    leg.distance_nm = distance
    leg.operating_cost = EconomyService.flight_cost(
        family, db.airports.get(origin_id, {}), db.airports.get(destination_id, {}), distance)

    var payload: Array[Job] = state.loaded_jobs(aircraft_id)
    var delivered: Array[Job] = []
    for job: Job in payload:
        if job.destination_id == destination_id:
            delivered.append(job)
    leg.expected_revenue = EconomyService.payload_revenue(delivered)

    var timeline: Dictionary = _build_timeline(family, distance, now_unix)
    leg.phase_ends = timeline["ends"]
    leg.departure_unix = now_unix
    leg.arrival_unix = now_unix + float(timeline["arrival"])

    plane.state = AircraftInstance.State.IN_FLIGHT
    plane.flight_id = leg.id
    plane.location_id = ""
    plane.stand_id = ""
    state.flights[leg.id] = leg
    return leg

## Where an aircraft is right now, for the world map. Ground phases sit at the
## airport they belong to, so a plane never jumps across the map mid-taxi.
func position_of(leg: FlightLeg, now_unix: float) -> Dictionary:
    var origin: Dictionary = db.airports.get(leg.origin_id, {})
    var destination: Dictionary = db.airports.get(leg.destination_id, {})
    if origin.is_empty() or destination.is_empty():
        return {"lat": 0.0, "lon": 0.0, "bearing": 0.0}
    var lat1: float = float(origin["lat"])
    var lon1: float = float(origin["lon"])
    var lat2: float = float(destination["lat"])
    var lon2: float = float(destination["lon"])
    var bearing: float = WorldProjection.bearing_degrees(lat1, lon1, lat2, lon2)

    var phase: FlightLeg.Phase = leg.phase_at(now_unix)
    if phase < FlightLeg.Phase.TAKEOFF_ROLL:
        return {"lat": lat1, "lon": lon1, "bearing": bearing}
    if phase > FlightLeg.Phase.LANDING_ROLL:
        return {"lat": lat2, "lon": lon2, "bearing": bearing}

    var t: float = leg.enroute_progress(now_unix)
    var point: Vector2 = WorldProjection.interpolate_great_circle(lat1, lon1, lat2, lon2, t)
    # Orient along the local tangent rather than the whole-leg bearing, so a
    # long curved route points the right way throughout.
    var ahead: Vector2 = WorldProjection.interpolate_great_circle(
        lat1, lon1, lat2, lon2, minf(1.0, t + 0.01))
    var local_bearing: float = WorldProjection.bearing_degrees(point.x, point.y, ahead.x, ahead.y)
    return {"lat": point.x, "lon": point.y, "bearing": local_bearing}

## Settles every flight that has finished. Safe to call at any time and any
## number of times: the settled flag makes payout exactly-once.
func settle_due(state: AirlineState, now_unix: float) -> Array[Dictionary]:
    var settlements: Array[Dictionary] = []
    for id: String in state.flights:
        var leg: FlightLeg = state.flights[id]
        if leg.settled or not leg.is_complete(now_unix):
            continue
        settlements.append(_settle(state, leg))
    return settlements

func _settle(state: AirlineState, leg: FlightLeg) -> Dictionary:
    leg.settled = true
    var plane: AircraftInstance = state.aircraft.get(leg.aircraft_id, null)
    var delivered: Array[Job] = []
    var carried_on: Array[String] = []

    for job_id: String in leg.payload_ids:
        var job: Job = state.jobs.get(job_id, null)
        if job == null:
            continue
        if job.destination_id == leg.destination_id:
            job.state = Job.State.DELIVERED
            job.aircraft_id = ""
            delivered.append(job)
        else:
            # Payload for a further stop stays aboard as a layover.
            carried_on.append(job_id)

    var revenue: int = EconomyService.payload_revenue(delivered)
    state.money += revenue - leg.operating_cost
    state.reputation += delivered.size()

    if plane != null:
        plane.state = AircraftInstance.State.PARKED
        plane.flight_id = ""
        plane.location_id = leg.destination_id
        plane.stand_id = free_stand(state, leg.destination_id)
        plane.loaded_job_ids = carried_on
        plane.legs += 1
        plane.hours += (leg.arrival_unix - leg.departure_unix) / 3600.0
        plane.lifetime_revenue += revenue
        # Wear is small and slow; condition is flavour, not a failure mechanic.
        plane.condition = maxf(0.35, plane.condition - leg.distance_nm * 0.00004)

    return {
        "flight_id": leg.id, "aircraft_id": leg.aircraft_id,
        "destination_id": leg.destination_id, "revenue": revenue,
        "cost": leg.operating_cost, "profit": revenue - leg.operating_cost,
        "delivered": delivered.size(),
    }
