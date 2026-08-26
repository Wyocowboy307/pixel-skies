extends TestCase
## Ground movement presentation. It must never teleport, and must never alter
## the flight it is reading.

const T0 := 1_800_000_000.0

func _setup() -> Dictionary:
    var db := GameDB.new()
    db.load_all()
    var clock := GameClock.new()
    clock.set_fixed(T0)
    var sim := Simulation.new(db, clock)
    sim.new_game()
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    var job := Job.new()
    job.id = sim.ids.next("job")
    job.kind = "passenger"
    job.origin_id = "apt_bzn"
    job.destination_id = "apt_bil"
    job.seats = 1
    job.reward = 400
    job.created_unix = T0
    job.expires_unix = T0 + 7200.0
    sim.state.jobs[job.id] = job
    var stand: String = plane.stand_id
    sim.load_job(plane.id, job.id)
    sim.dispatch(plane.id, "apt_bil")
    return {"sim": sim, "leg": sim.state.flights.values()[0], "stand": stand}

func test_departure_never_jumps() -> void:
    var setup: Dictionary = _setup()
    var leg: FlightLeg = setup["leg"]
    var sim: Simulation = setup["sim"]
    var layout: Dictionary = sim.db.layout_for_airport("apt_bzn")
    var previous := Vector2.INF
    # Sampled fine enough that a step is a fraction of a second. The takeoff
    # roll legitimately covers ~460 px in 12 s, so a coarse sweep reports large
    # steps that are speed, not teleports; only a dense sweep tests continuity.
    var samples := 6000
    var biggest := 0.0
    for i in range(samples + 1):
        var at: float = leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * float(i) / float(samples)
        var state: Dictionary = FlightGround.state(leg, "apt_bzn", layout, setup["stand"], at)
        if not bool(state["visible"]):
            continue
        var position: Vector2 = state["position"]
        if previous != Vector2.INF:
            biggest = maxf(biggest, previous.distance_to(position))
        previous = position
    # A jump between phases would show up as one huge step.
    var seconds_per_sample: float = (leg.arrival_unix - leg.departure_unix) / float(samples)
    # Nothing on the ground exceeds roughly 40 px/s, so anything much beyond
    # that in one step is a discontinuity rather than movement.
    var limit: float = maxf(6.0, 40.0 * seconds_per_sample * 4.0)
    check(biggest < limit, "largest ground step is %.1f px (limit %.1f) — that is a teleport"
        % [biggest, limit])

func test_takeoff_accelerates() -> void:
    var setup: Dictionary = _setup()
    var leg: FlightLeg = setup["leg"]
    var layout: Dictionary = (setup["sim"] as Simulation).db.layout_for_airport("apt_bzn")
    var order: Array = FlightLeg.phase_order()
    var roll_end: float = float(leg.phase_ends[FlightLeg.Phase.TAKEOFF_ROLL])
    var roll_start: float = float(leg.phase_ends[FlightLeg.Phase.TAXI_OUT])
    var early: Vector2 = FlightGround.state(leg, "apt_bzn", layout, setup["stand"],
        roll_start + (roll_end - roll_start) * 0.15)["position"]
    var early2: Vector2 = FlightGround.state(leg, "apt_bzn", layout, setup["stand"],
        roll_start + (roll_end - roll_start) * 0.25)["position"]
    var late: Vector2 = FlightGround.state(leg, "apt_bzn", layout, setup["stand"],
        roll_start + (roll_end - roll_start) * 0.85)["position"]
    var late2: Vector2 = FlightGround.state(leg, "apt_bzn", layout, setup["stand"],
        roll_start + (roll_end - roll_start) * 0.95)["position"]
    check(late.distance_to(late2) > early.distance_to(early2),
        "the aircraft must be moving faster at rotation than at brake release")

func test_arrival_ends_at_the_stand() -> void:
    var setup: Dictionary = _setup()
    var leg: FlightLeg = setup["leg"]
    var sim: Simulation = setup["sim"]
    var layout: Dictionary = sim.db.layout_for_airport("apt_bil")
    var stand := "stand_1"
    var state: Dictionary = FlightGround.state(leg, "apt_bil", layout, stand,
        leg.arrival_unix - 1.0)
    check(bool(state["visible"]), "the arriving aircraft is visible while unloading")
    var expected: Vector2 = Vector2(-64, -8)
    check(state["position"].distance_to(expected) < 4.0,
        "unloads on its stand, got %s" % state["position"])

func test_presentation_does_not_touch_the_flight() -> void:
    # The regression rule: camera and animation work must never change results.
    var setup: Dictionary = _setup()
    var leg: FlightLeg = setup["leg"]
    var layout: Dictionary = (setup["sim"] as Simulation).db.layout_for_airport("apt_bzn")
    var before: Dictionary = leg.to_dict()
    for i in range(50):
        var at: float = leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * float(i) / 50.0
        FlightGround.state(leg, "apt_bzn", layout, setup["stand"], at)
    check_eq(JSON.stringify(leg.to_dict()), JSON.stringify(before),
        "sampling ground state left the flight record unchanged")
