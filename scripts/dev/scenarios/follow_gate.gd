extends RefCounted
## Follow-mode terrain gate: dispatch BZN -> BIL, lock the camera to the
## aircraft and capture the corridor strip at three points of the crossing —
## plains, forest and mountains.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.4)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    var loaded := 0
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if job.destination_id == "apt_bil" and bool(sim.load_job(plane.id, job.id)["ok"]):
            loaded += 1
    if loaded == 0:
        # Dispatch needs at least one job aboard; any payload will do for a
        # presentation gate.
        for job: Job in sim.state.jobs_at("apt_bzn"):
            if bool(sim.load_job(plane.id, job.id)["ok"]):
                break
    var result: Dictionary = sim.dispatch(plane.id, "apt_bil")
    if not bool(result["ok"]):
        push_error("follow_gate: dispatch failed — %s" % String(result["reason"]))
        return
    var leg: FlightLeg = sim.state.flights[String(result["flight_id"])]

    # Follow the aircraft exactly the way a click on it would.
    main._followed_aircraft_id = plane.id
    main._overlay.selected_aircraft_id = plane.id

    var start: float = float(leg.phase_ends.get(FlightLeg.Phase.CLIMB, leg.departure_unix))
    var end: float = float(leg.phase_ends.get(FlightLeg.Phase.ENROUTE, leg.arrival_unix))
    var beats: Array = [
        [0.2, "follow_plains"],
        [0.5, "follow_forest"],
        [0.8, "follow_mountains"],
    ]
    for beat: Array in beats:
        sim.clock.set_fixed(start + (end - start) * float(beat[0]))
        await cap.wait(0.9)
        await cap.shot(String(beat[1]))
