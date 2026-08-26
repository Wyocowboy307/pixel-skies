extends RefCounted
## Plays the opening loop the way a new player would: open BZN, look at the job
## board, load the aircraft, choose a destination and depart.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    await cap.wait(0.4)

    main._on_airport_activated("apt_bzn")
    await cap.wait(1.6)
    await cap.shot("airport_with_jobs")

    var hud: AirportHud = main._airport_hud
    var sim: Simulation = main.sim
    var plane: AircraftInstance = sim.state.aircraft.values()[0]

    # Load whatever the board actually offers that will fit.
    var loaded := 0
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if bool(sim.load_job(plane.id, job.id)["ok"]):
            loaded += 1
        if loaded >= 4:
            break
    hud.refresh()
    await cap.wait(0.6)
    await cap.shot("loaded")

    hud._on_route_pressed()
    await cap.wait(0.6)
    await cap.shot("route_preview")

    var destination := ""
    for job: Job in sim.state.loaded_jobs(plane.id):
        destination = job.destination_id
        break
    if destination.is_empty():
        destination = "apt_bil"
    hud.selected_destination = destination
    hud._refresh_route()
    await cap.wait(0.5)
    await cap.shot("destination_chosen")

    hud._on_dispatch_pressed()
    await cap.wait(0.8)
    await cap.shot("departed")
