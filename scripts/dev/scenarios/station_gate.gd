extends RefCounted
## Station-upgrade gate: BZN's reserved lots empty, then every station upgrade
## built, so "upgrades visibly change the airport" can be judged on the
## composed scene.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    sim.state.money += 1000000
    WeatherService.set_override("apt_bzn", WeatherService.Kind.CLEAR)
    await cap.wait(0.4)

    main.enter_airport("apt_bzn")
    await cap.wait(1.2)
    await cap.shot("bzn_lots_empty")

    for upgrade_id: String in ["station_terminal_2", "station_cargo_1", "station_hangar_1"]:
        var result: Dictionary = sim.purchase_upgrade("apt_bzn", upgrade_id)
        if not bool(result.get("ok", false)):
            print("[station_gate] %s failed: %s" % [
                upgrade_id, String(result.get("reason", "?"))])
    main._airport_view.queue_redraw()
    await cap.wait(0.8)
    await cap.shot("bzn_all_built")

    # Pan to each lot so the built structures can be judged up close.
    main._airport_camera.follow(Vector2(-330.0, 120.0))   # hangar + annex, west
    await cap.wait(1.2)
    await cap.shot("bzn_built_west")
    main._airport_camera.follow(Vector2(420.0, 80.0))     # cargo shed, east
    await cap.wait(1.2)
    await cap.shot("bzn_built_east")
