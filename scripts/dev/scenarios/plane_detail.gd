extends RefCounted
## Reviews the plane detail screen: empty, part-loaded, and in flight.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.4)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.8)
    await cap.shot("detail_empty")

    # Load a mixed payload so both bays have something in them.
    var loaded := 0
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if bool(sim.load_job(plane.id, job.id)["ok"]):
            loaded += 1
        if loaded >= 5:
            break
    main._detail_view.refresh()
    await cap.wait(0.6)
    await cap.shot("detail_loaded")

    main._detail_view._toggle_refit()
    await cap.wait(0.5)
    await cap.shot("detail_refit")
    main._detail_view._toggle_refit()

    # In flight: the route strip should show progress and phase.
    var destination := "apt_den"
    for job: Job in sim.state.loaded_jobs(plane.id):
        destination = job.destination_id
        break
    main.close_aircraft_detail()
    await cap.wait(0.3)
    sim.dispatch(plane.id, destination)
    var leg: FlightLeg = sim.state.flights.values()[0]
    sim.clock.set_fixed(leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * 0.45)
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.8)
    await cap.shot("detail_in_flight")
