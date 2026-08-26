class_name Simulation
extends RefCounted
## The simulation facade: one place the presentation layer talks to.
##
## Emits committed domain events after state has already changed, so an
## animation can never be the authority for a payout
## (docs/TECH_ARCHITECTURE.md, "Events").

signal money_changed(money: int)
signal jobs_changed(airport_id: String)
signal job_loaded(job: Job, aircraft: AircraftInstance)
signal job_unloaded(job: Job, aircraft: AircraftInstance)
signal flight_dispatched(leg: FlightLeg)
signal flight_phase_changed(leg: FlightLeg, phase: FlightLeg.Phase)
signal flight_arrived(settlement: Dictionary)
signal aircraft_purchased(aircraft: AircraftInstance)
signal airport_upgraded(airport_id: String, upgrade_id: String)

var db: GameDB
var clock: GameClock
var ids: Ids
var state: AirlineState
var jobs: JobService
var flights: FlightService

## Last phase seen per flight, so phase transitions can be announced once each.
var _phase_cache: Dictionary = {}

func _init(database: GameDB, game_clock: GameClock = null) -> void:
    db = database
    clock = game_clock if game_clock != null else GameClock.new()
    ids = Ids.new()
    state = AirlineState.new()
    _rebuild_services()

func _rebuild_services() -> void:
    jobs = JobService.new(db, ids)
    flights = FlightService.new(db, ids)

func now() -> float:
    return clock.now()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func new_game() -> void:
    state = AirlineState.new()
    ids = Ids.new()
    _rebuild_services()
    _phase_cache.clear()

    for airport_id: String in db.airports:
        if bool((db.airports[airport_id] as Dictionary).get("starter_unlocked", false)):
            state.unlocked_airport_ids.append(airport_id)

    var starter: AircraftInstance = _create_aircraft("ac_trailhopper_4", state.home_base_id)
    starter.nickname = "Old Faithful"
    refresh_jobs()
    money_changed.emit(state.money)

## Restores a save and immediately reconciles everything that happened while the
## game was closed.
func load_game() -> bool:
    var saved: Dictionary = SaveService.load_saved()
    if saved.is_empty():
        return false
    state = saved["state"]
    ids = saved["ids"]
    _rebuild_services()
    _phase_cache.clear()
    catch_up()
    return true

func save_game() -> bool:
    return SaveService.save(state, ids, now())

## Resolves everything that became due while the game was not running: flights
## land, jobs expire, boards refill.
func catch_up() -> void:
    var current: float = now()
    _settle_due(current)
    expire_jobs(current)
    refresh_jobs()
    money_changed.emit(state.money)

## Called every frame by the presentation layer. Cheap: it only compares
## timestamps.
func tick() -> void:
    var current: float = now()
    _announce_phase_changes(current)
    _settle_due(current)

func _announce_phase_changes(current: float) -> void:
    for id: String in state.flights:
        var leg: FlightLeg = state.flights[id]
        if leg.settled:
            continue
        var phase: FlightLeg.Phase = leg.phase_at(current)
        if _phase_cache.get(id, -1) != phase:
            _phase_cache[id] = phase
            flight_phase_changed.emit(leg, phase)

func _settle_due(current: float) -> void:
    var settlements: Array[Dictionary] = flights.settle_due(state, current)
    if settlements.is_empty():
        return
    for settlement: Dictionary in settlements:
        _phase_cache.erase(String(settlement["flight_id"]))
        flight_arrived.emit(settlement)
        jobs_changed.emit(String(settlement["destination_id"]))
    money_changed.emit(state.money)

# ---------------------------------------------------------------------------
# Jobs
# ---------------------------------------------------------------------------

func refresh_jobs() -> void:
    var current: float = now()
    for airport_id: String in state.unlocked_airport_ids:
        var existing: Array[Job] = []
        for id: String in state.jobs:
            var job: Job = state.jobs[id]
            if job.origin_id == airport_id:
                existing.append(job)
        var created: Array[Job] = jobs.replenish(airport_id, existing, current)
        for job: Job in created:
            state.jobs[job.id] = job
        if not created.is_empty():
            jobs_changed.emit(airport_id)

func expire_jobs(current: float) -> void:
    var touched: Dictionary = {}
    for id: String in state.jobs:
        var job: Job = state.jobs[id]
        if job.has_expired(current):
            job.state = Job.State.EXPIRED
            touched[job.origin_id] = true
    for airport_id: Variant in touched:
        jobs_changed.emit(String(airport_id))

## Load a job onto an aircraft. Returns the rules verdict so the UI can print
## exactly one reason when it fails.
func load_job(aircraft_id: String, job_id: String) -> Dictionary:
    var plane: AircraftInstance = state.aircraft.get(aircraft_id, null)
    var job: Job = state.jobs.get(job_id, null)
    if plane == null or job == null:
        return Rules.no("That aircraft or job no longer exists")
    var family: Dictionary = db.aircraft.get(plane.family_id, {})
    var verdict: Dictionary = Rules.can_load(plane, family, job, state.loaded_jobs(aircraft_id))
    if not bool(verdict["ok"]):
        return verdict
    job.state = Job.State.LOADED
    job.aircraft_id = aircraft_id
    plane.loaded_job_ids.append(job_id)
    job_loaded.emit(job, plane)
    jobs_changed.emit(job.origin_id)
    return Rules.ok()

func unload_job(aircraft_id: String, job_id: String) -> Dictionary:
    var plane: AircraftInstance = state.aircraft.get(aircraft_id, null)
    var job: Job = state.jobs.get(job_id, null)
    if plane == null or job == null:
        return Rules.no("That aircraft or job no longer exists")
    if plane.state == AircraftInstance.State.IN_FLIGHT:
        return Rules.no("Cannot unload an aircraft in flight")
    plane.loaded_job_ids.erase(job_id)
    job.state = Job.State.AVAILABLE
    job.aircraft_id = ""
    job_unloaded.emit(job, plane)
    jobs_changed.emit(job.origin_id)
    return Rules.ok()

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

func dispatch_check(aircraft_id: String, destination_id: String) -> Dictionary:
    var plane: AircraftInstance = state.aircraft.get(aircraft_id, null)
    if plane == null:
        return Rules.no("No such aircraft")
    var family: Dictionary = db.aircraft.get(plane.family_id, {})
    var origin: Dictionary = db.airports.get(plane.location_id, {})
    var destination: Dictionary = db.airports.get(destination_id, {})
    var distance: float = flights.distance_between(plane.location_id, destination_id)
    return Rules.can_dispatch(plane, family, origin, destination, distance,
        state.loaded_jobs(aircraft_id))

## Time, cost, revenue and profit for a proposed leg — the dispatch preview.
func dispatch_preview(aircraft_id: String, destination_id: String) -> Dictionary:
    var plane: AircraftInstance = state.aircraft.get(aircraft_id, null)
    if plane == null:
        return {}
    var family: Dictionary = db.aircraft.get(plane.family_id, {})
    var origin: Dictionary = db.airports.get(plane.location_id, {})
    var destination: Dictionary = db.airports.get(destination_id, {})
    var distance: float = flights.distance_between(plane.location_id, destination_id)
    var duration: float = flights.estimate_duration(family, distance)
    return EconomyService.preview(family, origin, destination, distance,
        state.loaded_jobs(aircraft_id), duration)

func dispatch(aircraft_id: String, destination_id: String) -> Dictionary:
    var verdict: Dictionary = dispatch_check(aircraft_id, destination_id)
    if not bool(verdict["ok"]):
        return verdict
    var leg: FlightLeg = flights.dispatch(state, aircraft_id, destination_id, now())
    if leg == null:
        return Rules.no("Could not create the flight")
    _phase_cache[leg.id] = leg.phase_at(now())
    flight_dispatched.emit(leg)
    jobs_changed.emit(leg.origin_id)
    return {"ok": true, "reason": "", "flight_id": leg.id}

func flight_for_aircraft(aircraft_id: String) -> FlightLeg:
    var plane: AircraftInstance = state.aircraft.get(aircraft_id, null)
    if plane == null or plane.flight_id.is_empty():
        return null
    return state.flights.get(plane.flight_id, null)

# ---------------------------------------------------------------------------
# Fleet and stations
# ---------------------------------------------------------------------------

func _create_aircraft(family_id: String, airport_id: String) -> AircraftInstance:
    var family: Dictionary = db.aircraft.get(family_id, {})
    var plane := AircraftInstance.new()
    plane.id = ids.next("ac")
    plane.family_id = family_id
    plane.registration = ids.next_registration()
    plane.home_base_id = airport_id
    plane.location_id = airport_id
    plane.configuration = String(family.get("default_configuration", "mixed"))
    plane.stand_id = _free_stand(airport_id)
    state.aircraft[plane.id] = plane
    return plane

func _free_stand(airport_id: String) -> String:
    var layout: Dictionary = db.layout_for_airport(airport_id)
    var taken: Dictionary = {}
    for plane: AircraftInstance in state.aircraft_at(airport_id):
        taken[plane.stand_id] = true
    for entry: Variant in layout.get("stands", []):
        var stand_id: String = String((entry as Dictionary).get("id", ""))
        if not taken.has(stand_id):
            return stand_id
    return ""

func purchase_check(family_id: String) -> Dictionary:
    var family: Dictionary = db.aircraft.get(family_id, {})
    if family.is_empty():
        return Rules.no("Unknown aircraft type")
    var cost: int = int(family.get("purchase_cost", 0))
    if state.money < cost:
        return Rules.no("Need $%s — you have $%s" % [
            _money(cost), _money(state.money)])
    if _free_stand(state.home_base_id).is_empty():
        # Capacity comes from visible facilities, never an arbitrary slot fee
        # (CLAUDE.md, "Non-negotiable experience").
        return Rules.no("No free stand at %s — expand the station first" % state.home_base_id.to_upper().replace("APT_", ""))
    return Rules.ok()

func purchase_aircraft(family_id: String) -> Dictionary:
    var verdict: Dictionary = purchase_check(family_id)
    if not bool(verdict["ok"]):
        return verdict
    var family: Dictionary = db.aircraft.get(family_id, {})
    state.money -= int(family.get("purchase_cost", 0))
    var plane: AircraftInstance = _create_aircraft(family_id, state.home_base_id)
    aircraft_purchased.emit(plane)
    money_changed.emit(state.money)
    return Rules.ok()

func upgrade_check(airport_id: String, upgrade_id: String) -> Dictionary:
    var upgrade: Dictionary = db.airport_upgrades.get(upgrade_id, {})
    if upgrade.is_empty():
        return Rules.no("Unknown upgrade")
    if state.has_upgrade(airport_id, upgrade_id):
        return Rules.no("Already built")
    for required: Variant in upgrade.get("requires", []):
        if not state.has_upgrade(airport_id, String(required)):
            var name: String = String((db.airport_upgrades[String(required)] as Dictionary).get("name", required))
            return Rules.no("Requires %s first" % name)
    var cost: int = int(upgrade.get("cost", 0))
    if state.money < cost:
        return Rules.no("Need $%s — you have $%s" % [_money(cost), _money(state.money)])
    return Rules.ok()

func purchase_upgrade(airport_id: String, upgrade_id: String) -> Dictionary:
    var verdict: Dictionary = upgrade_check(airport_id, upgrade_id)
    if not bool(verdict["ok"]):
        return verdict
    state.money -= int((db.airport_upgrades[upgrade_id] as Dictionary).get("cost", 0))
    var built: Array = state.upgrades_by_airport.get(airport_id, [])
    built.append(upgrade_id)
    state.upgrades_by_airport[airport_id] = built
    airport_upgraded.emit(airport_id, upgrade_id)
    money_changed.emit(state.money)
    return Rules.ok()

static func _money(amount: int) -> String:
    var text: String = str(absi(amount))
    var out := ""
    var count := 0
    for i in range(text.length() - 1, -1, -1):
        out = text[i] + out
        count += 1
        if count % 3 == 0 and i > 0:
            out = "," + out
    return ("-" if amount < 0 else "") + out
