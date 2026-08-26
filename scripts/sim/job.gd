class_name Job
extends RefCounted
## One passenger party, cargo consignment or contract waiting at an airport.

enum State { AVAILABLE, LOADED, DELIVERED, EXPIRED }

var id := ""
var template_id := ""
var kind := "passenger"          ## passenger | cargo | contract
var origin_id := ""
var destination_id := ""
var seats := 0                   ## passenger jobs consume seats
var cargo_units := 0             ## cargo/contract jobs consume hold units
var reward := 0
var created_unix := 0.0
var expires_unix := 0.0
var presentation := ""           ## drives the sprite used in the load view
var urgency := "normal"
var state: State = State.AVAILABLE
var aircraft_id := ""            ## set while loaded

func is_available() -> bool:
    return state == State.AVAILABLE

func has_expired(now_unix: float) -> bool:
    return state == State.AVAILABLE and now_unix >= expires_unix

func seconds_remaining(now_unix: float) -> float:
    return maxf(0.0, expires_unix - now_unix)

## Short human description used by the job list and the load view.
func describe() -> String:
    if kind == "passenger":
        return "%d passenger%s" % [seats, "" if seats == 1 else "s"]
    return "%d crate%s" % [cargo_units, "" if cargo_units == 1 else "s"]

func to_dict() -> Dictionary:
    return {
        "id": id, "template_id": template_id, "kind": kind,
        "origin_id": origin_id, "destination_id": destination_id,
        "seats": seats, "cargo_units": cargo_units, "reward": reward,
        "created_unix": created_unix, "expires_unix": expires_unix,
        "presentation": presentation, "urgency": urgency,
        "state": int(state), "aircraft_id": aircraft_id,
    }

static func from_dict(data: Dictionary) -> Job:
    var job := Job.new()
    job.id = String(data.get("id", ""))
    job.template_id = String(data.get("template_id", ""))
    job.kind = String(data.get("kind", "passenger"))
    job.origin_id = String(data.get("origin_id", ""))
    job.destination_id = String(data.get("destination_id", ""))
    job.seats = int(data.get("seats", 0))
    job.cargo_units = int(data.get("cargo_units", 0))
    job.reward = int(data.get("reward", 0))
    job.created_unix = float(data.get("created_unix", 0.0))
    job.expires_unix = float(data.get("expires_unix", 0.0))
    job.presentation = String(data.get("presentation", ""))
    job.urgency = String(data.get("urgency", "normal"))
    job.state = data.get("state", State.AVAILABLE) as State
    job.aircraft_id = String(data.get("aircraft_id", ""))
    return job
