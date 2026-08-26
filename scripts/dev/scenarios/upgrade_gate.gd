extends RefCounted
## Art review gate: the upgrade shop — browse, preview, celebration, owned,
## and the broke state where every BUY explains itself.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    sim.state.money = 50000
    await cap.wait(0.5)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.5)

    var view: UpgradeView = null
    if main.has_method("open_upgrade"):
        main.open_upgrade(plane.id)
        view = main._upgrade_view
    else:
        # Main does not wire the shop in yet, so open it over the plane screen
        # exactly the way main will: on the UI layer, freed by closed().
        view = UpgradeView.new()
        view.theme = main._ui_theme
        main.get_node("UI").add_child(view)
        view.bind(sim, plane.id)
        view.closed.connect(view.queue_free)
    await cap.wait(0.6)
    await cap.shot("upgrade_screen")

    # Select a card so the CURRENT -> UPGRADED strip shows its promise.
    view.select_upgrade("up_cabin")
    await cap.wait(0.4)
    await cap.shot("upgrade_preview")

    # Buy through the view — it routes through sim.purchase_aircraft_upgrade
    # and then celebrates, which is the moment worth reviewing.
    view._on_buy("up_cabin")
    await cap.wait(0.1)
    await cap.shot("upgrade_celebrate")
    await cap.wait(0.22)
    await cap.shot("upgrade_celebrate_late")

    await cap.wait(1.0)
    view.refresh()
    await cap.wait(0.3)
    await cap.shot("upgrade_owned")

    # Broke airline: every BUY switches off and says why.
    sim.state.money = 3000
    view.refresh()
    await cap.wait(0.4)
    await cap.shot("upgrade_broke")
