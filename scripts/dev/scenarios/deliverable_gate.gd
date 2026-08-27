extends RefCounted
## The eight deliverable moments, captured in one deterministic run.

func _at(leg: FlightLeg, phase: int, fraction: float) -> float:
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
    WeatherService.set_override("apt_bzn", WeatherService.Kind.CLEAR)
    WeatherService.set_override("apt_bil", WeatherService.Kind.CLEAR)
    await cap.wait(0.5)

    # 1. Rebuilt BZN airport.
    main.enter_airport("apt_bzn")
    await cap.wait(1.6)
    await cap.shot("bzn_airport")

    # 2. Empty Trailhopper.
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    plane.configuration = "passenger"
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.9)
    await cap.shot("trailhopper_empty")

    # 3/4. Job loading animation + loaded plane.
    main._detail_view._set_mode("load")
    await cap.wait(0.5)
    var first := true
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.destination_id != "apt_bil" and job.seats == 0:
            continue
        if sim.load_job(plane.id, job.id)["ok"]:
            if first and main._detail_view._job_list.get_child_count() > 0:
                main._detail_view._on_load_job_visual(job) if main._detail_view.has_method("_on_load_job_visual") else null
            first = false
    main._detail_view.refresh()
    await cap.wait(0.2)
    await cap.shot("job_loading")
    await cap.wait(0.8)
    main._detail_view._set_mode("")
    main._detail_view.refresh()
    await cap.wait(0.5)
    await cap.shot("trailhopper_loaded")

    # 5. Customization.
    main.open_customize(plane.id)
    await cap.wait(0.8)
    await cap.shot("customize")
    main._close_overlay_screen()
    await cap.wait(0.3)
    main.close_aircraft_detail()
    await cap.wait(0.5)

    # 6. Takeoff.
    main._detail_return = main.View.WORLD
    sim.dispatch(plane.id, "apt_bil")
    var leg: FlightLeg = sim.state.flights.values()[0]
    if main._view != main.View.AIRPORT:
        main.enter_airport("apt_bzn")
    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.TAKEOFF_ROLL, 0.55))
    await cap.wait(1.2)
    await cap.shot("takeoff")

    # 7. Follow mode over terrain.
    main.exit_airport()
    await cap.wait(1.4)
    main._followed_aircraft_id = plane.id
    main._overlay.selected_aircraft_id = plane.id
    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.ENROUTE, 0.5))
    await cap.wait(1.6)
    await cap.shot("follow_mode")

    # 8. BIL landing / unloading.
    main._followed_aircraft_id = ""
    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.LANDING_ROLL, 0.3))
    main.enter_airport("apt_bil")
    await cap.wait(1.6)
    await cap.shot("bil_landing")
    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.UNLOADING, 0.5))
    await cap.wait(0.9)
    await cap.shot("bil_unloading")
    WeatherService.clear_overrides()
