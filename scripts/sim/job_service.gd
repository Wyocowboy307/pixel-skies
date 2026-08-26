class_name JobService
extends RefCounted
## Generates the job board at each airport.
##
## The list stays short and readable rather than eighty rows, and destinations
## are weighted toward places the airline can actually serve
## (docs/JOBS_ECONOMY_PROGRESSION.md, "Job generation").

## How many jobs a station shows at once, by airport tier.
const BOARD_SIZE := {"regional": 6, "major": 9}
## Patience window. Long enough that a job survives a round trip, short enough
## that the board keeps turning over.
const EXPIRY_SECONDS := {"passenger": 2700.0, "cargo": 3600.0, "contract": 5400.0}

var db: GameDB
var ids: Ids
var _rng := RandomNumberGenerator.new()

func _init(database: GameDB, id_source: Ids, seed_value: int = 0) -> void:
    db = database
    ids = id_source
    _rng.seed = seed_value if seed_value != 0 else 20260826

## Tops the board back up to its target size without disturbing jobs already
## listed, so the list does not reshuffle under the player's cursor.
func replenish(airport_id: String, existing: Array[Job], now_unix: float) -> Array[Job]:
    var airport: Dictionary = db.airports.get(airport_id, {})
    if airport.is_empty():
        return []
    var target: int = int(BOARD_SIZE.get(String(airport.get("tier", "regional")), 6))
    var available := 0
    for job: Job in existing:
        if job.is_available():
            available += 1
    var created: Array[Job] = []
    for _i in range(maxi(0, target - available)):
        var job: Job = _generate(airport, now_unix)
        if job != null:
            created.append(job)
    return created

func _generate(airport: Dictionary, now_unix: float) -> Job:
    var template: Dictionary = _pick_template(airport)
    if template.is_empty():
        return null
    var destination: Dictionary = _pick_destination(airport)
    if destination.is_empty():
        return null

    var job := Job.new()
    job.id = ids.next("job")
    job.template_id = String(template.get("id", ""))
    job.kind = String(template.get("kind", "passenger"))
    job.origin_id = String(airport.get("id", ""))
    job.destination_id = String(destination.get("id", ""))
    job.presentation = String(template.get("presentation", ""))
    job.urgency = String(template.get("urgency", "normal"))
    job.created_unix = now_unix
    job.expires_unix = now_unix + float(EXPIRY_SECONDS.get(job.kind, 3000.0))

    if job.kind == "passenger":
        job.seats = _rng.randi_range(
            int(template.get("party_size_min", 1)), int(template.get("party_size_max", 2)))
    else:
        var units_min: int = int(template.get("units_min", template.get("requires_cargo_units", 1)))
        var units_max: int = int(template.get("units_max", template.get("requires_cargo_units", 1)))
        job.cargo_units = _rng.randi_range(units_min, maxi(units_min, units_max))

    var distance: float = WorldProjection.great_circle_nm(
        float(airport["lat"]), float(airport["lon"]),
        float(destination["lat"]), float(destination["lon"]))
    job.reward = EconomyService.job_reward(job.kind, job.seats, job.cargo_units,
        distance, float(template.get("reward_multiplier", 1.0)), job.urgency)
    return job

## Template weights are biased by the airport's own demand profile, so a cargo
## town produces cargo and a tourist town produces passengers.
func _pick_template(airport: Dictionary) -> Dictionary:
    var entries: Array[Dictionary] = []
    var total := 0.0
    for id: String in db.job_templates:
        var template: Dictionary = db.job_templates[id]
        var weight: float = float(template.get("weight", 1))
        match String(template.get("kind", "")):
            "passenger":
                weight *= 0.5 + float(airport.get("passenger_demand", 0.5)) + float(airport.get("tourism", 0.0)) * 0.5
            "cargo":
                weight *= 0.5 + float(airport.get("cargo_demand", 0.5)) * 1.5
            "contract":
                weight *= 0.8
        entries.append({"template": template, "weight": weight})
        total += weight
    if total <= 0.0:
        return {}
    var roll: float = _rng.randf() * total
    for entry: Dictionary in entries:
        roll -= float(entry["weight"])
        if roll <= 0.0:
            return entry["template"]
    return entries[entries.size() - 1]["template"]

## Destinations favour bigger markets and shorter, more useful hops.
func _pick_destination(origin: Dictionary) -> Dictionary:
    var entries: Array[Dictionary] = []
    var total := 0.0
    for id: String in db.airports:
        if id == String(origin.get("id", "")):
            continue
        var candidate: Dictionary = db.airports[id]
        if not bool(candidate.get("starter_unlocked", false)):
            continue
        var weight: float = 0.4 + float(candidate.get("passenger_demand", 0.5))
        if String(candidate.get("tier", "")) == "major":
            # Big markets pull harder, but only a little: a board that is five
            # rows of the same city gives the player nothing to choose between.
            weight *= 1.15
        entries.append({"airport": candidate, "weight": weight})
        total += weight
    if total <= 0.0:
        return {}
    var roll: float = _rng.randf() * total
    for entry: Dictionary in entries:
        roll -= float(entry["weight"])
        if roll <= 0.0:
            return entry["airport"]
    return entries[entries.size() - 1]["airport"]
