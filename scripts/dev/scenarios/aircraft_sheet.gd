extends RefCounted
## Renders the aircraft silhouette review sheet over the running game.

const Sheet = preload("res://scripts/dev/aircraft_sheet.gd")

func run(cap) -> void:
    var main: Node = cap.get_tree().current_scene
    await cap.wait(0.4)

    var layer := CanvasLayer.new()
    layer.layer = 50
    var sheet: Control = Sheet.new()
    sheet.db = main.db
    layer.add_child(sheet)
    main.add_child(layer)

    await cap.wait(0.4)
    await cap.shot("aircraft_silhouettes")
    layer.queue_free()
