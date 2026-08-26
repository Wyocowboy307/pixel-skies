extends RefCounted
## Airport life and weather gate: BZN in clear air, under snow and rain, then a
## boarding crowd filing out to a loading Trailhopper.

func _at(sim: Simulation, leg: FlightLeg, phase: int, fraction: float) -> float:
    var order: Array = FlightLeg.phase_order()
    var index: int = order.find(phase)
    var ends: float = float(leg.phase_ends.get(phase, leg.arrival_unix))
    var starts: float = leg.departure_unix if index <= 0 \
        else float(leg.phase_ends.get(order[index - 1], leg.departure_unix))
    return starts + (ends - starts) * fraction

## Blinking lights spend most of the time dark; hold the capture until the
## aircraft's beacon window opens so the shot shows the field alive.
func _await_beacon(cap, view: AirportView, plane_id: String) -> void:
    var offset: float = float(absi(hash(plane_id)) % 100) / 100.0
    for _i in range(240):
        if fposmod(view._clock + offset, 1.2) < 0.2:
            return
        await cap.get_tree().process_frame

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.5)

    # A calm day at BZN: cart on patrol, worker at the depot, masts blinking.
    WeatherService.set_override("apt_bzn", WeatherService.Kind.CLEAR)
    main._on_airport_activated("apt_bzn")
    await cap.wait(1.8)
    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    await _await_beacon(cap, main._airport_view, plane.id)
    await cap.shot("bzn_clear")

    WeatherService.set_override("apt_bzn", WeatherService.Kind.SNOW)
    await cap.wait(1.6)
    await cap.shot("bzn_snow")

    WeatherService.set_override("apt_bzn", WeatherService.Kind.RAIN)
    await cap.wait(1.6)
    await cap.shot("bzn_rain")

    # Board a flight: load a job, dispatch, hold the clock mid-LOADING so the
    # travellers file from the terminal out to the aircraft.
    WeatherService.set_override("apt_bzn", WeatherService.Kind.CLEAR)
    plane.configuration = "passenger"
    var destination := ""
    for job: Job in sim.state.jobs_at("apt_bzn"):
        if bool(sim.load_job(plane.id, job.id)["ok"]):
            destination = job.destination_id
            break
    if destination.is_empty():
        destination = "apt_bil"
    var result: Dictionary = sim.dispatch(plane.id, destination)
    if bool(result.get("ok", false)):
        var leg: FlightLeg = sim.state.flights[String(result["flight_id"])]
        sim.clock.set_fixed(_at(sim, leg, FlightLeg.Phase.LOADING, 0.5))
    else:
        push_error("airport_life_gate: dispatch failed (%s)" % String(result.get("reason", "")))
    await cap.wait(2.2)
    await _await_beacon(cap, main._airport_view, plane.id)
    await cap.shot("bzn_boarding")

    WeatherService.clear_overrides()
