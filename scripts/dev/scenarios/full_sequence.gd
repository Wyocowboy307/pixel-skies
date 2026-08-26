extends RefCounted
## The whole vertical slice: BZN -> BIL on one Trailhopper, captured at every
## beat of the sequence.

func _at(sim: Simulation, leg: FlightLeg, phase: int, fraction: float) -> float:
    var order: Array = FlightLeg.phase_order()
    var index: int = order.find(phase)
    var ends: float = float(leg.phase_ends.get(phase, leg.arrival_unix))
    var starts: float = leg.departure_unix if index <= 0 \
        else float(leg.phase_ends.get(order[index - 1], leg.departure_unix))
    return starts + (ends - starts) * fraction

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.4)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    plane.configuration = "passenger"

    # 1. Pick a job on the plane screen.
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.7)
    main._detail_view._set_mode("load")
    await cap.wait(0.5)
    await cap.shot("01_pick_job")

    # 2. Load passengers bound for BIL.
    var loaded := 0
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.destination_id == "apt_bil" and bool(sim.load_job(plane.id, job.id)["ok"]):
            loaded += 1
    if loaded == 0:
        for job: Job in sim.state.jobs_at("apt_bzn"):
            if bool(sim.load_job(plane.id, job.id)["ok"]):
                break
    main._detail_view.refresh()
    await cap.wait(0.6)
    await cap.shot("02_loaded")

    # 3. Choose BIL.
    main._detail_view._set_mode("route")
    main._detail_view._selected_destination = "apt_bil"
    main._detail_view._mode = ""
    main._detail_view.refresh()
    await cap.wait(0.5)
    await cap.shot("03_route_chosen")

    # 4. Fly.
    main._detail_view._on_fly()
    await cap.wait(1.6)
    var leg: FlightLeg = sim.state.flights.values()[0]

    # 5..7 Departure, watched from the airfield.
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.TAXI_OUT, 0.45))
    await cap.wait(0.6)
    await cap.shot("04_taxi_out")
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.TAKEOFF_ROLL, 0.6))
    await cap.wait(0.5)
    await cap.shot("05_takeoff_roll")
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.CLIMB, 0.35))
    await cap.wait(0.5)
    await cap.shot("06_lift_off")

    # 8. Handoff to the world, following the aircraft.
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.ENROUTE, 0.10))
    await cap.wait(1.8)
    main._camera.focus_on(WorldProjection.to_world(45.8, -109.8), 4)
    await cap.wait(0.8)
    await cap.shot("07_enroute_follow")

    # 9..11 Arrival at BIL.
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.APPROACH, 0.75))
    await cap.wait(1.9)
    await cap.shot("08_approach")
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.LANDING_ROLL, 0.25))
    await cap.wait(0.6)
    await cap.shot("09_touchdown")
    sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.TAXI_IN, 0.55))
    await cap.wait(0.6)
    await cap.shot("10_taxi_in")

    # 12. Unload and payout.
    sim.clock.set_fixed(leg.arrival_unix + 2.0)
    await cap.wait(1.0)
    await cap.shot("11_arrived_paid")
