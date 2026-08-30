extends RefCounted
## Aircraft-identity gate: every family's side view on the plane screen and in
## the paint shop, so silhouette and livery language can be judged together.
## Purchases happen at DEN (five stands) so the whole fleet fits at once.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    sim.state.money += 1000000
    sim.state.home_base_id = "apt_den"
    await cap.wait(0.4)

    var families: Array = ["ac_trailhopper_4", "ac_twinwing_8", "ac_highline_19"]
    for family_id: String in families:
        var owned: AircraftInstance = null
        for plane: AircraftInstance in sim.state.aircraft.values():
            if plane.family_id == family_id:
                owned = plane
        if owned == null:
            var result: Dictionary = sim.purchase_aircraft(family_id)
            if not bool(result.get("ok", false)):
                print("[fleet_gate] purchase failed for %s: %s" % [
                    family_id, String(result.get("reason", "?"))])
                continue
            for plane: AircraftInstance in sim.state.aircraft.values():
                if plane.family_id == family_id:
                    owned = plane
        if owned == null:
            continue
        var short_name: String = family_id.trim_prefix("ac_")
        main.open_aircraft_detail(owned.id)
        await cap.wait(0.8)
        await cap.shot("detail_%s" % short_name)
        main.open_customize(owned.id)
        await cap.wait(0.6)
        await cap.shot("paint_%s" % short_name)
        main._customize_view.closed.emit()
        await cap.wait(0.3)
        main.close_aircraft_detail()
        await cap.wait(0.4)
