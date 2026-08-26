class_name AirlineState
extends RefCounted
## Everything the player owns and everything in flight.
##
## Pure data with no scene dependencies, so the whole simulation can run and be
## tested headless (docs/TECH_ARCHITECTURE.md, "Simulation must run without scenes").

const SAVE_VERSION := 1
const STARTING_MONEY := 32000

var save_version := SAVE_VERSION
var money := STARTING_MONEY
var reputation := 0
var home_base_id := "apt_bzn"
var unlocked_airport_ids: Array[String] = []
var upgrades_by_airport: Dictionary = {}     ## airport_id -> Array[String]
var aircraft: Dictionary = {}                ## aircraft_id -> AircraftInstance
var jobs: Dictionary = {}                    ## job_id -> Job
var flights: Dictionary = {}                 ## flight_id -> FlightLeg
var tutorial_step := 0
var last_seen_unix := 0.0

func aircraft_at(airport_id: String) -> Array[AircraftInstance]:
    var out: Array[AircraftInstance] = []
    for id: String in aircraft:
        var plane: AircraftInstance = aircraft[id]
        if plane.location_id == airport_id and plane.state != AircraftInstance.State.IN_FLIGHT:
            out.append(plane)
    return out

func active_flights() -> Array[FlightLeg]:
    var out: Array[FlightLeg] = []
    for id: String in flights:
        var leg: FlightLeg = flights[id]
        if not leg.settled:
            out.append(leg)
    return out

func jobs_at(airport_id: String) -> Array[Job]:
    var out: Array[Job] = []
    for id: String in jobs:
        var job: Job = jobs[id]
        if job.origin_id == airport_id and job.is_available():
            out.append(job)
    return out

func loaded_jobs(aircraft_id: String) -> Array[Job]:
    var plane: AircraftInstance = aircraft.get(aircraft_id, null)
    var out: Array[Job] = []
    if plane == null:
        return out
    for job_id: String in plane.loaded_job_ids:
        var job: Job = jobs.get(job_id, null)
        if job != null:
            out.append(job)
    return out

func jobs_for_flight(leg: FlightLeg) -> Array[Job]:
    var out: Array[Job] = []
    for job_id: String in leg.payload_ids:
        var job: Job = jobs.get(job_id, null)
        if job != null:
            out.append(job)
    return out

func upgrades_at(airport_id: String) -> Array[String]:
    var raw: Array = upgrades_by_airport.get(airport_id, [])
    var out: Array[String] = []
    for entry: Variant in raw:
        out.append(String(entry))
    return out

func has_upgrade(airport_id: String, upgrade_id: String) -> bool:
    return upgrades_at(airport_id).has(upgrade_id)

func fleet_summary() -> Dictionary:
    var flying := 0
    for id: String in aircraft:
        if (aircraft[id] as AircraftInstance).state == AircraftInstance.State.IN_FLIGHT:
            flying += 1
    return {"total": aircraft.size(), "flying": flying}

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
    var aircraft_data: Dictionary = {}
    for id: String in aircraft:
        aircraft_data[id] = (aircraft[id] as AircraftInstance).to_dict()
    var job_data: Dictionary = {}
    for id: String in jobs:
        job_data[id] = (jobs[id] as Job).to_dict()
    var flight_data: Dictionary = {}
    for id: String in flights:
        flight_data[id] = (flights[id] as FlightLeg).to_dict()
    return {
        "save_version": save_version, "money": money, "reputation": reputation,
        "home_base_id": home_base_id,
        "unlocked_airport_ids": unlocked_airport_ids.duplicate(),
        "upgrades_by_airport": upgrades_by_airport.duplicate(true),
        "aircraft": aircraft_data, "jobs": job_data, "flights": flight_data,
        "tutorial_step": tutorial_step, "last_seen_unix": last_seen_unix,
    }

static func from_dict(data: Dictionary) -> AirlineState:
    var state := AirlineState.new()
    state.save_version = int(data.get("save_version", SAVE_VERSION))
    state.money = int(data.get("money", STARTING_MONEY))
    state.reputation = int(data.get("reputation", 0))
    state.home_base_id = String(data.get("home_base_id", "apt_bzn"))
    state.tutorial_step = int(data.get("tutorial_step", 0))
    state.last_seen_unix = float(data.get("last_seen_unix", 0.0))
    var unlocked: Array[String] = []
    for entry: Variant in data.get("unlocked_airport_ids", []):
        unlocked.append(String(entry))
    state.unlocked_airport_ids = unlocked
    state.upgrades_by_airport = (data.get("upgrades_by_airport", {}) as Dictionary).duplicate(true)
    for id: Variant in data.get("aircraft", {}):
        state.aircraft[String(id)] = AircraftInstance.from_dict((data["aircraft"] as Dictionary)[id])
    for id: Variant in data.get("jobs", {}):
        state.jobs[String(id)] = Job.from_dict((data["jobs"] as Dictionary)[id])
    for id: Variant in data.get("flights", {}):
        state.flights[String(id)] = FlightLeg.from_dict((data["flights"] as Dictionary)[id])
    return state
