class_name WorldCamera
extends Camera2D

const ZOOM_STOPS := [0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
var zoom_index := 2
var panning := false

func _ready() -> void:
    zoom = Vector2.ONE * float(ZOOM_STOPS[zoom_index])

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _step_zoom(1)
            get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _step_zoom(-1)
            get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_MIDDLE:
            panning = event.pressed
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and panning:
        global_position -= event.relative / maxf(zoom.x, 0.001)
        get_viewport().set_input_as_handled()

func _step_zoom(direction: int) -> void:
    var before := get_global_mouse_position()
    zoom_index = clampi(zoom_index + direction, 0, ZOOM_STOPS.size() - 1)
    zoom = Vector2.ONE * float(ZOOM_STOPS[zoom_index])
    var after := get_global_mouse_position()
    global_position += before - after
