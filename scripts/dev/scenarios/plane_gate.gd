extends RefCounted
## Art review gate: the plane screen empty, partly loaded and full.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.4)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    # Passenger layout so all four seats are available for the review.
    plane.configuration = "passenger"
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.7)
    await cap.shot("empty")

    main._detail_view._set_mode("load")
    await cap.wait(0.6)
    await cap.shot("job_list_open")

    # Load one passenger job and catch the payload mid-flight to its seat.
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.seats > 0 and bool(sim.load_job(plane.id, job.id)["ok"]):
            var card: Control = main._detail_view._job_list.get_child(0)
            main._detail_view._in_transit.append({
                "t": 0.0, "from": Vector2(90.0, 120.0),
                "to": main._detail_view._slot_screen_position(true, 0),
                "seat": true, "variant": 0, "kind": "",
            })
            break
    main._detail_view.refresh()
    await cap.wait(0.18)
    await cap.shot("loading_in_flight")

    await cap.wait(0.8)
    await cap.shot("partly_loaded")

    # Fill it up.
    for job: Job in sim.state.jobs_at("apt_bzn"):
        sim.load_job(plane.id, job.id)
    plane.configuration = "passenger"
    main._detail_view._set_mode("")
    main._detail_view.refresh()
    await cap.wait(0.6)
    await cap.shot("fully_loaded")

    main._detail_view._details_open = true
    main._detail_view._refresh_details()
    await cap.wait(0.5)
    await cap.shot("details_open")
