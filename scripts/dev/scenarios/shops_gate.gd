extends RefCounted
## Art review gate for the two shops: the paint shop before and after a
## recolour, then the upgrade shop previewing a kit on the plane and the
## moment right after buying it.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var sim: Simulation = main.sim
    sim.clock.set_fixed(Time.get_unix_time_from_system())
    sim.state.money = 50000
    await cap.wait(0.5)

    var plane: AircraftInstance = sim.state.aircraft.values()[0]
    main.open_aircraft_detail(plane.id)
    await cap.wait(0.4)

    # Paint shop: hero plane in factory cream, then a full recolour.
    main.open_customize(plane.id)
    await cap.wait(0.6)
    await cap.shot("paint_before")

    sim.customize_aircraft(plane.id, {
        "livery_body": "sky",
        "livery_accent": "yellow",
        "livery_tail": "mint",
    })
    main._customize_view.refresh()
    await cap.wait(0.4)
    await cap.shot("paint_after")

    # Hand back to the plane screen, then into the upgrade shop.
    main._customize_view.closed.emit()
    await cap.wait(0.3)
    main.open_upgrade(plane.id)
    await cap.wait(0.6)

    var view: UpgradeView = main._upgrade_view
    # Focus the cabin kit: the strip promises the seats and ghost seats
    # appear beside the fuselage.
    view.select_upgrade("up_cabin")
    await cap.wait(0.8)
    await cap.shot("upgrade_preview")

    # Buy it mid-celebration: flash, hop, confetti, and the seat count
    # climbing on the strip.
    view._on_buy("up_cabin")
    await cap.wait(0.35)
    await cap.shot("upgrade_bought")
