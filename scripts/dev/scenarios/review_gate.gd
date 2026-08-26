extends RefCounted
## The milestone review gate: every screenshot the brief requires, in one
## deterministic run. This is what "done" is judged against.

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
    WeatherService.clear_overrides()
    await cap.wait(0.5)

    # -- 1. Full world map -------------------------------------------------
    main._camera.focus_on(WorldProjection.to_world(30.0, -40.0), 0)
    await cap.wait(1.2)
    await cap.shot("world_full")

    # -- Fleet staging: three aircraft in the air --------------------------
    sim.state.money = 500000
    var starter: AircraftInstance = sim.state.aircraft.values()[0]
    starter.configuration = "passenger"
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.destination_id == "apt_bil" and job.seats > 0:
            sim.load_job(starter.id, job.id)
    if sim.state.loaded_jobs(starter.id).is_empty():
        for job: Job in sim.state.jobs_at("apt_bzn"):
            if sim.load_job(starter.id, job.id)["ok"]:
                break
    sim.dispatch(starter.id, "apt_bil")

    sim.purchase_aircraft("ac_twinwing_8")
    var twin: AircraftInstance = null
    for plane: AircraftInstance in sim.state.aircraft.values():
        if plane.family_id == "ac_twinwing_8":
            twin = plane
    if twin != null:
        for job: Job in sim.state.jobs_at("apt_bzn"):
            if sim.load_job(twin.id, job.id)["ok"]:
                break
        sim.dispatch(twin.id, "apt_den")
    sim.purchase_aircraft("ac_trailhopper_4")
    var third: AircraftInstance = null
    for plane: AircraftInstance in sim.state.aircraft.values():
        if plane.id != starter.id and plane.family_id == "ac_trailhopper_4":
            third = plane
    if third != null:
        sim.customize_aircraft(third.id, {"livery_body": "sky", "livery_accent": "yellow"})
        for job: Job in sim.state.jobs_at("apt_bzn"):
            if sim.load_job(third.id, job.id)["ok"]:
                break
        sim.dispatch(third.id, "apt_den")

    # -- 2. Busy regional map ----------------------------------------------
    var starter_leg: FlightLeg = sim.flight_for_aircraft(starter.id)
    sim.clock.set_fixed(_at(starter_leg, FlightLeg.Phase.ENROUTE, 0.4))
    main._overlay.selected_aircraft_id = starter.id
    main._camera.focus_on(WorldProjection.to_world(44.2, -108.5), 3)
    await cap.wait(1.4)
    await cap.shot("regional_busy")

    # -- 9. Follow mode -----------------------------------------------------
    main._followed_aircraft_id = starter.id
    main._camera.focus_on(main._overlay.aircraft_world_position(starter.id), 4)
    await cap.wait(1.2)
    await cap.shot("follow_mode")

    # -- 10. Landing ---------------------------------------------------------
    main._followed_aircraft_id = ""
    sim.clock.set_fixed(_at(starter_leg, FlightLeg.Phase.LANDING_ROLL, 0.3))
    main.enter_airport("apt_bil")
    await cap.wait(1.6)
    await cap.shot("landing")
    main.exit_airport()
    await cap.wait(1.2)

    # -- Settle everything and go home to BZN -------------------------------
    sim.clock.set_fixed(sim.now() + 7200.0)
    sim.catch_up()

    # -- 3/4. Cabin empty and full ------------------------------------------
    var home: AircraftInstance = null
    for plane: AircraftInstance in sim.state.aircraft.values():
        if plane.location_id == "apt_bzn" and plane.is_available():
            home = plane
            break
    if home == null:
        home = starter
        home.state = AircraftInstance.State.PARKED
        home.location_id = "apt_bzn"
        home.stand_id = "stand_1"
    home.configuration = "passenger"
    sim.refresh_jobs()
    main.open_aircraft_detail(home.id)
    await cap.wait(1.0)
    await cap.shot("cabin_empty")

    for job: Job in sim.state.jobs_at(home.location_id):
        sim.load_job(home.id, job.id)
    main._detail_view.refresh()
    await cap.wait(0.7)
    await cap.shot("cabin_full")

    # -- 5. Customize --------------------------------------------------------
    main.open_customize(home.id)
    await cap.wait(0.9)
    await cap.shot("customize")
    main._close_overlay_screen()
    await cap.wait(0.3)

    # -- 6. Upgrade ----------------------------------------------------------
    main.open_upgrade(home.id)
    await cap.wait(0.9)
    await cap.shot("upgrade")
    main._close_overlay_screen()
    await cap.wait(0.3)
    main.close_aircraft_detail()
    await cap.wait(0.5)

    # -- 7. BZN daytime ------------------------------------------------------
    if main._view != main.View.AIRPORT:
        main.enter_airport("apt_bzn")
    await cap.wait(1.4)
    await cap.shot("bzn_day")

    # -- 8. BZN bad weather --------------------------------------------------
    WeatherService.set_override("apt_bzn", WeatherService.Kind.SNOW)
    await cap.wait(1.4)
    await cap.shot("bzn_snow")
    WeatherService.clear_overrides()
