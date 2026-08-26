extends RefCounted
## Art review gate: the paint shop with the default livery, then recoloured.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    await cap.wait(0.5)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.4)
    main.open_customize(plane.id)
    await cap.wait(0.6)
    await cap.shot("customize_default")

    sim.customize_aircraft(plane.id, {
        "livery_body": "sky",
        "livery_accent": "yellow",
        "livery_tail": "mint",
    })
    main._customize_view.refresh()
    await cap.wait(0.4)
    await cap.shot("customize_recoloured")
