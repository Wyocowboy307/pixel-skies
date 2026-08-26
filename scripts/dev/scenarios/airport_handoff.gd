extends RefCounted
## Reviews the world -> airport handoff and each authored airport layout.

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    await cap.wait(0.5)

    main._on_airport_activated("apt_bzn")
    await cap.wait(1.6)
    await cap.shot("airport_bzn")

    main.exit_airport()
    await cap.wait(1.4)
    await cap.shot("back_to_world")

    main._on_airport_activated("apt_den")
    await cap.wait(1.6)
    await cap.shot("airport_den")

    main.exit_airport()
    await cap.wait(1.2)
    main._on_airport_activated("apt_bil")
    await cap.wait(1.6)
    await cap.shot("airport_bil")
