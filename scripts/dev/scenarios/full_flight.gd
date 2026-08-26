extends RefCounted
## The whole vertical-slice loop: open BZN, load, depart, watch the aircraft
## cross the map, and arrive. The clock is driven forward directly so a leg that
## takes an hour of game time can be reviewed in a few seconds.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    # A fixed clock makes the capture reproducible instead of depending on how
    # long the harness happened to take.
    sim.clock.set_fixed(Time.get_unix_time_from_system())

    await cap.wait(0.4)
    main._on_airport_activated("apt_bzn")
    await cap.wait(1.5)

    var hud: AirportHud = main._airport_hud
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    var destination := "apt_den"
    var loaded := 0
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.destination_id != destination:
            continue
        if bool(sim.load_job(plane.id, job.id)["ok"]):
            loaded += 1
    if loaded == 0:
        for job: Job in sim.state.jobs_at("apt_bzn"):
            if bool(sim.load_job(plane.id, job.id)["ok"]):
                destination = job.destination_id
                break
    hud.refresh()
    await cap.wait(0.5)
    await cap.shot("loaded_at_bzn")

    hud._on_route_pressed()
    hud.selected_destination = destination
    hud._refresh_route()
    await cap.wait(0.5)
    await cap.shot("route_chosen")

    hud._on_dispatch_pressed()
    await cap.wait(0.6)
    await cap.shot("departing")

    var leg: FlightLeg = sim.state.flights.values()[0]

    # Back out to the world and watch the aircraft actually move.
    main.exit_airport()
    await cap.wait(1.4)
    # Frame the leg itself: at world zoom the whole route is a few dozen pixels,
    # so watching a flight means being zoomed into the region.
    var midpoint: Vector2 = WorldProjection.interpolate_great_circle(
        45.7775, -111.152, 39.8561, -104.6737, 0.5)
    main._camera.focus_on(WorldProjection.to_world(midpoint.x, midpoint.y), 4)
    await cap.wait(1.0)
    await cap.shot("world_after_departure")

    for fraction: float in [0.25, 0.55, 0.85]:
        sim.clock.set_fixed(leg.departure_unix + (leg.arrival_unix - leg.departure_unix) * fraction)
        await cap.wait(0.7)
        await cap.shot("enroute_%d" % int(fraction * 100.0))

    # Arrive: settlement happens from the timestamp, not from the animation.
    sim.clock.set_fixed(leg.arrival_unix + 2.0)
    await cap.wait(0.9)
    await cap.shot("arrived")

    main._on_airport_activated(destination)
    await cap.wait(1.5)
    await cap.shot("parked_at_destination")
