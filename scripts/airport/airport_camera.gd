class_name AirportCamera
extends Camera2D
## Camera for the local airport scene.
##
## Frames the apron by default — that is where loading and departures happen —
## and lets the player pull back to see the whole field. Clamped to the layout
## bounds so the scene never drifts off into empty space.

const ZOOM_MIN := 0.42
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.25
const LERP_SPEED := 12.0

var bounds := Rect2(-750, -450, 1500, 900)
var _target_zoom := 0.85
var _target_position := Vector2.ZERO
var _panning := false

func frame(layout_bounds: Rect2, focus: Vector2, initial_zoom: float) -> void:
    bounds = layout_bounds
    _target_zoom = clampf(initial_zoom, ZOOM_MIN, ZOOM_MAX)
    zoom = Vector2.ONE * _target_zoom
    _target_position = focus
    global_position = focus
    _clamp_target()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
            _zoom_by(ZOOM_STEP, button.position)
            get_viewport().set_input_as_handled()
        elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
            _zoom_by(1.0 / ZOOM_STEP, button.position)
            get_viewport().set_input_as_handled()
        elif button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
            _panning = button.pressed
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _panning:
        _target_position -= (event as InputEventMouseMotion).relative / zoom
        global_position = _target_position
        _clamp_target()
        get_viewport().set_input_as_handled()

func _zoom_by(factor: float, anchor: Vector2) -> void:
    var before: Vector2 = _screen_to_world(anchor, _target_zoom)
    _target_zoom = clampf(_target_zoom * factor, ZOOM_MIN, ZOOM_MAX)
    var after: Vector2 = _screen_to_world(anchor, _target_zoom)
    _target_position += before - after
    _clamp_target()

func _screen_to_world(screen_pos: Vector2, zoom_level: float) -> Vector2:
    return _target_position + (screen_pos - get_viewport_rect().size * 0.5) / maxf(zoom_level, 0.001)

func _process(delta: float) -> void:
    var t: float = clampf(delta * LERP_SPEED, 0.0, 1.0)
    if absf(zoom.x - _target_zoom) > 0.001:
        zoom = Vector2.ONE * lerpf(zoom.x, _target_zoom, t)
    if global_position.distance_to(_target_position) > 0.5:
        global_position = global_position.lerp(_target_position, t)
    else:
        global_position = _target_position

## Keeps the field on screen. When the view is wider than the layout, the axis
## is simply centred rather than fighting the clamp.
func _clamp_target() -> void:
    var half: Vector2 = get_viewport_rect().size * 0.5 / maxf(_target_zoom, 0.001)
    var margin := 120.0
    var low: Vector2 = bounds.position - Vector2(margin, margin) + half
    var high: Vector2 = bounds.position + bounds.size + Vector2(margin, margin) - half
    _target_position.x = _clamp_axis(_target_position.x, low.x, high.x, bounds.position.x + bounds.size.x * 0.5)
    _target_position.y = _clamp_axis(_target_position.y, low.y, high.y, bounds.position.y + bounds.size.y * 0.5)

func _clamp_axis(value: float, low: float, high: float, centre: float) -> float:
    if low > high:
        return centre
    return clampf(value, low, high)
