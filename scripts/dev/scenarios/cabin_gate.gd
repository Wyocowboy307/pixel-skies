extends RefCounted
## Art review gate for the cabin strip: empty, mid-boarding, and packed full.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.4)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    plane.configuration = "passenger"
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.7)
    await cap.shot("cabin_empty")

    # Board one passenger job and catch the hop mid-flight to its seat.
    main._detail_view._set_mode("load")
    await cap.wait(0.5)
    var boarded := false
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.seats > 0 and Rules.can_load(plane, sim.family_of(plane), job,
                sim.state.loaded_jobs(plane.id))["ok"]:
            var card: Control = main._detail_view._job_list.get_child(0)
            main._detail_view._on_load_job(job, card)
            boarded = true
            break
    if not boarded:
        main._detail_view.refresh()
    await cap.wait(0.16)
    await cap.shot("cabin_boarding")
    await cap.wait(0.8)

    # Fill every seat and the hold, then close the panel for the beauty shot.
    for job: Job in sim.state.jobs_at("apt_bzn"):
        sim.load_job(plane.id, job.id)
    main._detail_view._set_mode("")
    main._detail_view._in_transit.clear()
    main._detail_view.refresh()
    await cap.wait(0.6)
    await cap.shot("cabin_full")
