extends RefCounted
## Reviews the world map at each zoom tier and the airport focus transition.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    var camera: WorldCamera = main.get_node("WorldCamera")
    var overlay: WorldOverlay = main.get_node("UI/WorldOverlay")

    await cap.wait(0.5)
    await cap.shot("open_on_home_station")

    camera.focus_on(WorldProjection.to_world(20.0, -30.0), 0)
    await cap.wait(1.1)
    await cap.shot("whole_world")

    camera.focus_on(WorldProjection.to_world(45.0, -108.0), 1)
    await cap.wait(1.1)
    await cap.shot("continental")

    # Selection card + highlighted routes.
    overlay.selected_airport_id = "apt_bzn"
    main._on_airport_clicked("apt_bzn")
    camera.focus_on(WorldProjection.to_world(45.7775, -111.152), 2)
    await cap.wait(1.1)
    await cap.shot("bzn_selected")

    main._on_airport_activated("apt_den")
    await cap.wait(1.3)
    await cap.shot("den_focus_transition")
