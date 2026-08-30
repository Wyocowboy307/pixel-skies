extends RefCounted
## The composed DEN hub: the parked scene, then a busy arrival moment —
## touchdown on the main runway, taxi in past the gates, unloading on a stand.

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
    WeatherService.set_override("apt_den", WeatherService.Kind.CLEAR)
    await cap.wait(0.5)

    main.enter_airport("apt_den")
    await cap.wait(1.6)
    await cap.shot("den_parked")

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if sim.load_job(plane.id, job.id)["ok"]:
            break
    sim.dispatch(plane.id, "apt_den")
    var leg: FlightLeg = sim.state.flights.values()[0]

    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.LANDING_ROLL, 0.35))
    await cap.wait(1.2)
    await cap.shot("den_touchdown")

    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.TAXI_IN, 0.6))
    await cap.wait(0.8)
    await cap.shot("den_taxi_in")

    sim.clock.set_fixed(_at(leg, FlightLeg.Phase.UNLOADING, 0.5))
    await cap.wait(0.9)
    await cap.shot("den_unloading")
    WeatherService.clear_overrides()
