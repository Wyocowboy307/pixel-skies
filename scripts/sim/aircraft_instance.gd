class_name AircraftInstance
extends RefCounted
## One owned aircraft. The family record in data/aircraft.json holds the stats;
## this holds everything that makes a particular airframe *yours*
## (docs/AIRCRAFT_SYSTEM.md, "Personal attachment").

enum State { PARKED, LOADING, IN_FLIGHT }

var id := ""
var family_id := ""
var registration := ""
var nickname := ""
var livery := "house"
var home_base_id := ""
## Where the aircraft physically is. Empty only while airborne.
var location_id := ""
var stand_id := ""
var state: State = State.PARKED
var flight_id := ""
var loaded_job_ids: Array[String] = []
var configuration := "mixed"
var condition := 1.0
var hours := 0.0
var legs := 0
var lifetime_revenue := 0

func display_name() -> String:
    return nickname if not nickname.is_empty() else registration

func is_available() -> bool:
    return state != State.IN_FLIGHT and flight_id.is_empty()

func to_dict() -> Dictionary:
    return {
        "id": id, "family_id": family_id, "registration": registration,
        "nickname": nickname, "livery": livery, "home_base_id": home_base_id,
        "location_id": location_id, "stand_id": stand_id, "state": int(state),
        "flight_id": flight_id, "loaded_job_ids": loaded_job_ids.duplicate(),
        "configuration": configuration, "condition": condition,
        "hours": hours, "legs": legs, "lifetime_revenue": lifetime_revenue,
    }

static func from_dict(data: Dictionary) -> AircraftInstance:
    var aircraft := AircraftInstance.new()
    aircraft.id = String(data.get("id", ""))
    aircraft.family_id = String(data.get("family_id", ""))
    aircraft.registration = String(data.get("registration", ""))
    aircraft.nickname = String(data.get("nickname", ""))
    aircraft.livery = String(data.get("livery", "house"))
    aircraft.home_base_id = String(data.get("home_base_id", ""))
    aircraft.location_id = String(data.get("location_id", ""))
    aircraft.stand_id = String(data.get("stand_id", ""))
    aircraft.state = data.get("state", State.PARKED) as State
    aircraft.flight_id = String(data.get("flight_id", ""))
    aircraft.configuration = String(data.get("configuration", "mixed"))
    aircraft.condition = float(data.get("condition", 1.0))
    aircraft.hours = float(data.get("hours", 0.0))
    aircraft.legs = int(data.get("legs", 0))
    aircraft.lifetime_revenue = int(data.get("lifetime_revenue", 0))
    var loaded: Array[String] = []
    for entry: Variant in data.get("loaded_job_ids", []):
        loaded.append(String(entry))
    aircraft.loaded_job_ids = loaded
    return aircraft
