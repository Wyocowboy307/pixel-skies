extends RefCounted
## Art review gate for world-map presence and the visual job cards:
## a followed flight with its callsign chip and clouds mid-route, then the
## plane screen's job cards empty-ish and completely full.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.5)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    plane.nickname = "Bluebird"

    # A second aircraft bound for DEN with a head start, so the nearby-traffic
    # registration tag has something to label away from the hero.
    var wingman: AircraftInstance = sim._create_aircraft("ac_trailhopper_4", "apt_bzn")
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if bool(sim.load_job(wingman.id, job.id)["ok"]):
            break
    sim.dispatch(wingman.id, "apt_den")
    sim.clock.advance(1500.0)

    # Load one job, then fly BZN -> BIL and freeze the clock mid-ENROUTE.
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if bool(sim.load_job(plane.id, job.id)["ok"]):
            break
    var result: Dictionary = sim.dispatch(plane.id, "apt_bil")
    if not bool(result["ok"]):
        push_error("map_jobs_gate: dispatch failed: %s" % String(result["reason"]))
        return
    var leg: FlightLeg = sim.state.flights[String(result["flight_id"])]

    sim.clock.set_fixed(leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * 0.5)

    main._overlay.selected_aircraft_id = plane.id
    main._followed_aircraft_id = plane.id
    var bzn: Dictionary = sim.db.airports["apt_bzn"]
    var bil: Dictionary = sim.db.airports["apt_bil"]
    var midpoint: Vector2 = WorldProjection.interpolate_great_circle(
        float(bzn["lat"]), float(bzn["lon"]), float(bil["lat"]), float(bil["lon"]), 0.5)
    main._camera.focus_on(WorldProjection.to_world(midpoint.x, midpoint.y), 4)
    await cap.wait(1.4)
    await cap.shot("map_callsign_clouds")

    # Fly it back so the plane is standing at BZN again with jobs on the board.
    sim.clock.set_fixed(leg.arrival_unix + 5.0)
    sim.tick()
    sim.refresh_jobs()
    for job: Job in sim.state.jobs_at("apt_bil"):
        if bool(sim.load_job(plane.id, job.id)["ok"]):
            break
    var back: Dictionary = sim.dispatch(plane.id, "apt_bzn")
    if bool(back["ok"]):
        var home_leg: FlightLeg = sim.state.flights[String(back["flight_id"])]
        sim.clock.set_fixed(home_leg.arrival_unix + 5.0)
        sim.tick()
    sim.refresh_jobs()
    main._followed_aircraft_id = ""
    main._overlay.selected_aircraft_id = ""

    # The plane screen with the new visual job cards.
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.7)
    main._detail_view._set_mode("load")
    await cap.wait(0.6)
    await cap.shot("job_cards")

    # Fill the plane completely: every remaining card must say why it can't go.
    for job: Job in sim.state.jobs_at(plane.location_id):
        sim.load_job(plane.id, job.id)
    main._detail_view.refresh()
    await cap.wait(0.6)
    await cap.shot("job_cards_full")

    # Route cards get the same visual treatment; one destination is chosen.
    main._detail_view._selected_destination = "apt_bil"
    main._detail_view._set_mode("route")
    await cap.wait(0.6)
    await cap.shot("route_cards")
