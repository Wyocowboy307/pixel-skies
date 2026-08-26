extends TestCase
## Save/resume must reconstruct flights, not merely remember numbers
## (docs/TECH_ARCHITECTURE.md, "Save model").

const T0 := 1_800_000_000.0

func _sim() -> Simulation:
    var db := GameDB.new()
    db.load_all()
    var clock := GameClock.new()
    clock.set_fixed(T0)
    var sim := Simulation.new(db, clock)
    sim.new_game()
    return sim

func _reload(source: Simulation, at_unix: float) -> Simulation:
    source.save_game()
    var db := GameDB.new()
    db.load_all()
    var clock := GameClock.new()
    clock.set_fixed(at_unix)
    var restored := Simulation.new(db, clock)
    check(restored.load_game(), "save file loaded")
    return restored

func test_round_trip_preserves_the_airline() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 12345
    sim.state.reputation = 7
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    plane.nickname = "Old Faithful"

    var restored: Simulation = _reload(sim, T0)
    check_eq(restored.state.money, 12345, "money survives")
    check_eq(restored.state.reputation, 7, "reputation survives")
    check_eq(restored.state.aircraft.size(), 1, "fleet survives")
    var loaded_plane: AircraftInstance = restored.state.aircraft.values()[0]
    check_eq(loaded_plane.nickname, "Old Faithful", "aircraft identity survives")
    check_eq(loaded_plane.registration, plane.registration, "registration survives")

func test_flight_in_progress_survives_a_restart() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    var job := Job.new()
    job.id = sim.ids.next("job")
    job.kind = "passenger"
    job.origin_id = "apt_bzn"
    job.destination_id = "apt_den"
    job.seats = 1
    job.reward = 900
    job.created_unix = T0
    job.expires_unix = T0 + 7200.0
    sim.state.jobs[job.id] = job
    sim.load_job(plane.id, job.id)
    sim.dispatch(plane.id, "apt_den")
    var leg: FlightLeg = sim.state.flights.values()[0]

    # Reopen the game halfway through the leg.
    var midpoint: float = leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * 0.5
    var restored: Simulation = _reload(sim, midpoint)
    var restored_leg: FlightLeg = restored.state.flights.values()[0]
    check(not restored_leg.settled, "the flight is still running")
    # Timestamps round-trip through JSON, so compare with a tolerance far below
    # anything gameplay can notice rather than demanding bit equality.
    check_near(restored_leg.arrival_unix, leg.arrival_unix, 0.001, "arrival timestamp is unchanged")
    check_eq(restored_leg.phase_at(midpoint), leg.phase_at(midpoint), "phase is reconstructed identically")
    var position: Dictionary = restored.flights.position_of(restored_leg, midpoint)
    check(float(position["lat"]) < 45.7775, "the aircraft is somewhere south of Bozeman")
    check(float(position["lat"]) > 39.8561, "and has not reached Denver yet")

func test_flight_that_finished_while_closed_pays_on_load() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    var job := Job.new()
    job.id = sim.ids.next("job")
    job.kind = "cargo"
    job.origin_id = "apt_bzn"
    job.destination_id = "apt_bil"
    job.cargo_units = 1
    job.reward = 400
    job.created_unix = T0
    job.expires_unix = T0 + 7200.0
    sim.state.jobs[job.id] = job
    sim.load_job(plane.id, job.id)
    var before: int = sim.state.money
    sim.dispatch(plane.id, "apt_bil")
    var leg: FlightLeg = sim.state.flights.values()[0]

    var restored: Simulation = _reload(sim, leg.arrival_unix + 3600.0)
    check(restored.state.money > before, "the completed flight paid out on load")
    var loaded_plane: AircraftInstance = restored.state.aircraft.values()[0]
    check_eq(loaded_plane.location_id, "apt_bil", "the aircraft is at its destination")
    # And loading again must not pay a second time.
    var money_after: int = restored.state.money
    var twice: Simulation = _reload(restored, leg.arrival_unix + 7200.0)
    check_eq(twice.state.money, money_after, "reloading does not pay again")

func test_generated_ids_do_not_collide_after_reload() -> void:
    var sim: Simulation = _sim()
    var restored: Simulation = _reload(sim, T0)
    var fresh_id: String = restored.ids.next("job")
    check(not restored.state.jobs.has(fresh_id), "a new id does not reuse an existing one")

func test_save_version_is_recorded_and_migrated() -> void:
    var sim: Simulation = _sim()
    sim.save_game()
    var raw: Dictionary = SaveService.load_saved()
    check_eq(int((raw["state"] as AirlineState).save_version), AirlineState.SAVE_VERSION,
        "save records its schema version")
    var ancient: Dictionary = SaveService.migrate({"save_version": 0})
    check_eq(int(ancient["save_version"]), AirlineState.SAVE_VERSION, "old saves migrate forward")
