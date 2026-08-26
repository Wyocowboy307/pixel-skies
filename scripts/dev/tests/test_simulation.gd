extends TestCase
## Simulation behaviour, all on a fixed clock so results never depend on how
## fast the machine ran (docs/TESTING.md, "Automated simulation tests").

const T0 := 1_800_000_000.0

func _sim() -> Simulation:
    var db := GameDB.new()
    db.load_all()
    var clock := GameClock.new()
    clock.set_fixed(T0)
    var sim := Simulation.new(db, clock)
    sim.new_game()
    return sim

func _starter(sim: Simulation) -> AircraftInstance:
    return sim.state.aircraft.values()[0]

## Puts a known job of the requested shape on the board, so tests never depend
## on what random generation happened to produce.
func _make_job(sim: Simulation, destination: String, seats: int, units: int) -> Job:
    var job := Job.new()
    job.id = sim.ids.next("job")
    job.kind = "passenger" if seats > 0 else "cargo"
    job.origin_id = "apt_bzn"
    job.destination_id = destination
    job.seats = seats
    job.cargo_units = units
    job.reward = 500
    job.created_unix = T0
    job.expires_unix = T0 + 3600.0
    sim.state.jobs[job.id] = job
    return job

# ---------------------------------------------------------------------------
# Starting state
# ---------------------------------------------------------------------------

func test_new_game_starts_with_one_trailhopper_at_bzn() -> void:
    var sim: Simulation = _sim()
    check_eq(sim.state.aircraft.size(), 1, "fleet size at start")
    var plane: AircraftInstance = _starter(sim)
    check_eq(plane.family_id, "ac_trailhopper_4", "starter aircraft type")
    check_eq(plane.location_id, "apt_bzn", "starter parked at home base")
    check(not plane.stand_id.is_empty(), "starter is assigned a stand")
    check(sim.state.money > 0, "airline starts with money")

func test_new_game_generates_a_readable_job_board() -> void:
    var sim: Simulation = _sim()
    var board: Array[Job] = sim.state.jobs_at("apt_bzn")
    check_between(float(board.size()), 4.0, 12.0, "BZN board size is readable, not eighty rows")
    for job: Job in board:
        check(job.destination_id != "apt_bzn", "job does not route back to its origin")
        check(job.reward > 0, "job pays something")
        check(job.seats > 0 or job.cargo_units > 0, "job occupies seats or hold")

# ---------------------------------------------------------------------------
# Capacity and legality
# ---------------------------------------------------------------------------

func test_payload_capacity_is_enforced() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    # The Trailhopper's combi configuration carries 2 seats and 2 hold units.
    var limits: Dictionary = Rules.capacity(sim.db.aircraft[plane.family_id], plane.configuration)
    var seats: int = int(limits["seats"])

    var first: Job = _make_job(sim, "apt_bil", seats, 0)
    check(bool(sim.load_job(plane.id, first.id)["ok"]), "a load within capacity is accepted")

    var overflow: Job = _make_job(sim, "apt_bil", 1, 0)
    var verdict: Dictionary = sim.load_job(plane.id, overflow.id)
    check(not bool(verdict["ok"]), "loading past the seat count is refused")
    check(String(verdict["reason"]).to_lower().contains("seat"), "refusal explains it is about seats")

func test_cargo_and_seats_are_separate_pools() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var limits: Dictionary = Rules.capacity(sim.db.aircraft[plane.family_id], plane.configuration)
    var passengers: Job = _make_job(sim, "apt_bil", int(limits["seats"]), 0)
    var freight: Job = _make_job(sim, "apt_bil", 0, int(limits["cargo_units"]))
    check(bool(sim.load_job(plane.id, passengers.id)["ok"]), "seats fill")
    check(bool(sim.load_job(plane.id, freight.id)["ok"]), "a full cabin still has a free hold")

func test_range_legality() -> void:
    var sim: Simulation = _sim()
    var trailhopper: Dictionary = sim.db.aircraft["ac_trailhopper_4"]
    var bzn: Dictionary = sim.db.airports["apt_bzn"]
    var den: Dictionary = sim.db.airports["apt_den"]
    var reachable: Dictionary = Rules.can_fly(trailhopper, bzn, den, 480.0)
    check(bool(reachable["ok"]), "Denver is inside Trailhopper range")
    var too_far: Dictionary = Rules.can_fly(trailhopper, bzn, den, 900.0)
    check(not bool(too_far["ok"]), "a leg beyond range is refused")
    check(String(too_far["reason"]).to_lower().contains("range"), "refusal names range")

func test_runway_legality() -> void:
    var sim: Simulation = _sim()
    var highline: Dictionary = sim.db.aircraft["ac_highline_19"]
    var bzn: Dictionary = sim.db.airports["apt_bzn"]
    var short_field: Dictionary = sim.db.airports["apt_bil"].duplicate()
    short_field["runway_band"] = 1
    var verdict: Dictionary = Rules.can_fly(highline, bzn, short_field, 100.0)
    check(not bool(verdict["ok"]), "a short runway refuses a big aircraft")
    check(String(verdict["reason"]).to_lower().contains("runway"), "refusal names the runway")

# ---------------------------------------------------------------------------
# Dispatch and settlement
# ---------------------------------------------------------------------------

func test_dispatch_creates_exactly_one_flight() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var job: Job = _make_job(sim, "apt_bil", 1, 0)
    sim.load_job(plane.id, job.id)
    check(bool(sim.dispatch(plane.id, "apt_bil")["ok"]), "dispatch is accepted")
    check_eq(sim.state.flights.size(), 1, "exactly one flight exists")
    check_eq(plane.state, AircraftInstance.State.IN_FLIGHT, "aircraft is flying")

func test_aircraft_cannot_be_on_two_flights() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    sim.load_job(plane.id, _make_job(sim, "apt_bil", 1, 0).id)
    sim.dispatch(plane.id, "apt_bil")
    var second: Dictionary = sim.dispatch(plane.id, "apt_den")
    check(not bool(second["ok"]), "a flying aircraft cannot be dispatched again")
    check_eq(sim.state.flights.size(), 1, "no second flight was created")

func test_dispatch_requires_a_payload() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var verdict: Dictionary = sim.dispatch(plane.id, "apt_bil")
    check(not bool(verdict["ok"]), "an empty aircraft is not dispatched")

func test_flight_progresses_through_phases_in_order() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    sim.load_job(plane.id, _make_job(sim, "apt_bil", 1, 0).id)
    sim.dispatch(plane.id, "apt_bil")
    var leg: FlightLeg = sim.state.flights.values()[0]

    check_eq(leg.phase_at(T0), FlightLeg.Phase.LOADING, "starts loading")
    var previous: int = -1
    var samples := 60
    for i in range(samples + 1):
        var at: float = leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * float(i) / float(samples)
        var phase: int = leg.phase_at(at)
        check(phase >= previous, "phases never run backwards")
        previous = phase
    check_eq(leg.phase_at(leg.arrival_unix), FlightLeg.Phase.COMPLETE, "ends complete")

func test_short_hop_duration_is_in_the_designed_band() -> void:
    var sim: Simulation = _sim()
    var trailhopper: Dictionary = sim.db.aircraft["ac_trailhopper_4"]
    var bzn_bil: float = sim.flights.distance_between("apt_bzn", "apt_bil")
    var minutes: float = sim.flights.estimate_duration(trailhopper, bzn_bil) / 60.0
    # docs/FLIGHT_SYSTEM.md: a very short hop should be roughly 5-20 minutes.
    check_between(minutes, 5.0, 25.0, "BZN->BIL gate to gate minutes")

func test_faster_aircraft_is_quicker_over_the_same_leg() -> void:
    var sim: Simulation = _sim()
    var distance: float = sim.flights.distance_between("apt_bzn", "apt_den")
    var slow: float = sim.flights.estimate_duration(sim.db.aircraft["ac_trailhopper_4"], distance)
    var fast: float = sim.flights.estimate_duration(sim.db.aircraft["ac_highline_19"], distance)
    check(fast < slow, "the Highline beats the Trailhopper to Denver")

func test_payout_happens_exactly_once() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var job: Job = _make_job(sim, "apt_bil", 1, 0)
    sim.load_job(plane.id, job.id)
    var money_before: int = sim.state.money
    sim.dispatch(plane.id, "apt_bil")
    var leg: FlightLeg = sim.state.flights.values()[0]

    sim.clock.set_fixed(leg.arrival_unix + 1.0)
    sim.tick()
    var money_after: int = sim.state.money
    check_eq(money_after, money_before + job.reward - leg.operating_cost, "settled once, correctly")

    # Ticking repeatedly must not pay again.
    for _i in range(5):
        sim.clock.advance(60.0)
        sim.tick()
    check_eq(sim.state.money, money_after, "repeat ticks do not pay twice")

func test_arrival_moves_the_aircraft_and_delivers_the_job() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var job: Job = _make_job(sim, "apt_bil", 1, 0)
    sim.load_job(plane.id, job.id)
    sim.dispatch(plane.id, "apt_bil")
    var leg: FlightLeg = sim.state.flights.values()[0]
    sim.clock.set_fixed(leg.arrival_unix + 1.0)
    sim.tick()

    check_eq(plane.location_id, "apt_bil", "aircraft is now at the destination")
    check_eq(plane.state, AircraftInstance.State.PARKED, "aircraft is parked again")
    check_eq(job.state, Job.State.DELIVERED, "job is delivered")
    check(plane.loaded_job_ids.is_empty(), "delivered payload left the aircraft")
    check_eq(plane.legs, 1, "leg counted toward the airframe's history")
    # Without a stand the airport scene has nowhere to draw the arrival.
    check(not plane.stand_id.is_empty(), "arriving aircraft is given a stand")

func test_two_aircraft_do_not_share_a_stand() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 999999
    check(bool(sim.purchase_aircraft("ac_trailhopper_4")["ok"]), "second aircraft bought")
    var stands: Dictionary = {}
    for id: String in sim.state.aircraft:
        var plane: AircraftInstance = sim.state.aircraft[id]
        check(not plane.stand_id.is_empty(), "%s has a stand" % plane.registration)
        check(not stands.has(plane.stand_id), "stand %s is not double-booked" % plane.stand_id)
        stands[plane.stand_id] = true

func test_layover_payload_stays_aboard() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var for_bil: Job = _make_job(sim, "apt_bil", 1, 0)
    var for_den: Job = _make_job(sim, "apt_den", 1, 0)
    sim.load_job(plane.id, for_bil.id)
    sim.load_job(plane.id, for_den.id)
    sim.dispatch(plane.id, "apt_bil")
    var leg: FlightLeg = sim.state.flights.values()[0]
    sim.clock.set_fixed(leg.arrival_unix + 1.0)
    sim.tick()

    check_eq(for_bil.state, Job.State.DELIVERED, "the BIL job is delivered")
    check_eq(for_den.state, Job.State.LOADED, "the Denver job is still aboard")
    check(plane.loaded_job_ids.has(for_den.id), "layover payload stayed on the aircraft")

func test_offline_completion_settles_without_the_game_running() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    var job: Job = _make_job(sim, "apt_den", 2, 0)
    sim.load_job(plane.id, job.id)
    var before: int = sim.state.money
    sim.dispatch(plane.id, "apt_den")
    var leg: FlightLeg = sim.state.flights.values()[0]

    # Jump a week ahead without a single tick in between.
    sim.clock.set_fixed(leg.arrival_unix + 7.0 * 86400.0)
    sim.catch_up()
    check(sim.state.money > before, "the flight paid out after a long absence")
    check_eq(plane.location_id, "apt_den", "the aircraft arrived while the game was closed")

func test_job_expiry() -> void:
    var sim: Simulation = _sim()
    var job: Job = _make_job(sim, "apt_bil", 1, 0)
    sim.clock.set_fixed(job.expires_unix + 1.0)
    sim.expire_jobs(sim.now())
    check_eq(job.state, Job.State.EXPIRED, "an unclaimed job expires")
    check(not sim.state.jobs_at("apt_bzn").has(job), "expired jobs leave the board")

# ---------------------------------------------------------------------------
# Progression
# ---------------------------------------------------------------------------

func test_cannot_buy_what_you_cannot_afford() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 100
    var verdict: Dictionary = sim.purchase_aircraft("ac_highline_19")
    check(not bool(verdict["ok"]), "an unaffordable aircraft is refused")
    check_eq(sim.state.aircraft.size(), 1, "no aircraft was created")

func test_upgrade_prerequisites_are_enforced() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 999999
    var blocked: Dictionary = sim.purchase_upgrade("apt_bzn", "station_hangar_1")
    check(not bool(blocked["ok"]), "the hangar needs its prerequisite")
    check(bool(sim.purchase_upgrade("apt_bzn", "station_terminal_2")["ok"]), "the terminal builds")
    check(bool(sim.purchase_upgrade("apt_bzn", "station_hangar_1")["ok"]), "then the hangar builds")
    check(sim.state.has_upgrade("apt_bzn", "station_hangar_1"), "the upgrade is recorded")

func test_upgrade_is_charged_once() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 999999
    var before: int = sim.state.money
    var cost: int = int((sim.db.airport_upgrades["station_cargo_1"] as Dictionary)["cost"])
    sim.purchase_upgrade("apt_bzn", "station_cargo_1")
    check_eq(sim.state.money, before - cost, "charged the listed price")
    sim.purchase_upgrade("apt_bzn", "station_cargo_1")
    check_eq(sim.state.money, before - cost, "buying the same upgrade twice is refused")

# ---------------------------------------------------------------------------
# Aircraft upgrades
# ---------------------------------------------------------------------------

func test_aircraft_upgrade_changes_capacity_and_range() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 999999
    var plane: AircraftInstance = _starter(sim)
    plane.configuration = "passenger"
    var before: Dictionary = Rules.capacity(sim.family_of(plane), plane.configuration)
    var base_range: float = float(sim.family_of(plane).get("range_nm", 0.0))

    check(bool(sim.purchase_aircraft_upgrade(plane.id, "up_cabin")["ok"]), "cabin upgrade bought")
    check(bool(sim.purchase_aircraft_upgrade(plane.id, "up_tanks")["ok"]), "tanks bought")

    var after: Dictionary = Rules.capacity(sim.family_of(plane), plane.configuration)
    check_eq(int(after["seats"]), int(before["seats"]) + 2, "two more seats")
    check_near(float(sim.family_of(plane).get("range_nm", 0.0)), base_range + 160.0, 0.01,
        "range extended by the tanks")

func test_aircraft_upgrade_is_charged_exactly_once() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 999999
    var plane: AircraftInstance = _starter(sim)
    var before: int = sim.state.money
    sim.purchase_aircraft_upgrade(plane.id, "up_hold")
    var cost: int = before - sim.state.money
    check(cost > 0, "upgrade cost money")
    var again: Dictionary = sim.purchase_aircraft_upgrade(plane.id, "up_hold")
    check(not bool(again["ok"]), "buying the same upgrade twice is refused")
    check_eq(sim.state.money, before - cost, "not charged twice")

func test_aircraft_upgrade_needs_money() -> void:
    var sim: Simulation = _sim()
    sim.state.money = 10
    var plane: AircraftInstance = _starter(sim)
    check(not bool(sim.purchase_aircraft_upgrade(plane.id, "up_cabin")["ok"]),
        "an unaffordable upgrade is refused")

func test_customize_records_livery_and_nickname() -> void:
    var sim: Simulation = _sim()
    var plane: AircraftInstance = _starter(sim)
    sim.customize_aircraft(plane.id, {
        "nickname": "Sky Biscuit", "livery_body": "sky", "livery_accent": "yellow",
        "livery_tail": "mint"})
    check_eq(plane.nickname, "Sky Biscuit", "nickname stored")
    check_eq(plane.livery_body, "sky", "body scheme stored")
    check_eq(plane.livery_tail, "mint", "tail scheme stored")
