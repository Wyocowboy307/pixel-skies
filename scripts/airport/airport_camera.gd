class_name AirportCamera
extends Camera2D
## Camera for the local airport scene.
##
## Frames the apron by default — that is where loading and departures happen —
## and lets the player pull back to see the whole field. Clamped to the layout
## bounds so the scene never drifts off into empty space.

## Integer zoom only. A fractional zoom resamples every tile and sprite, which
## is exactly what the pixel style forbids (docs/PIXEL_STYLE_GUIDE.md).
const ZOOM_STOPS: Array[float] = [1.0, 2.0]
const LERP_SPEED := 14.0

var bounds := Rect2(-750, -450, 1500, 900)
var _zoom_index := 0
var _target_zoom := 1.0
var _target_position := Vector2.ZERO
var _panning := false

func frame(layout_bounds: Rect2, focus: Vector2, initial_zoom: float) -> void:
    bounds = layout_bounds
    _zoom_index = ZOOM_STOPS.find(initial_zoom)
    if _zoom_index < 0:
        _zoom_index = 0
    _target_zoom = ZOOM_STOPS[_zoom_index]
    zoom = Vector2.ONE * _target_zoom
    _target_position = focus
    global_position = focus
    _clamp_target()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
            _step_zoom(1, button.position)
            get_viewport().set_input_as_handled()
        elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
            _step_zoom(-1, button.position)
            get_viewport().set_input_as_handled()
        elif button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
            _panning = button.pressed
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _panning:
        _target_position -= (event as InputEventMouseMotion).relative / zoom
        global_position = _target_position
        _clamp_target()
        get_viewport().set_input_as_handled()

func _step_zoom(direction: int, anchor: Vector2) -> void:
    var next: int = clampi(_zoom_index + direction, 0, ZOOM_STOPS.size() - 1)
    if next == _zoom_index:
        return
    _zoom_index = next
    var before: Vector2 = _screen_to_world(anchor, _target_zoom)
    _target_zoom = ZOOM_STOPS[_zoom_index]
    var after: Vector2 = _screen_to_world(anchor, _target_zoom)
    _target_position += before - after
    _clamp_target()

func _screen_to_world(screen_pos: Vector2, zoom_level: float) -> Vector2:
    return _target_position + (screen_pos - get_viewport_rect().size * 0.5) / maxf(zoom_level, 0.001)

func _process(delta: float) -> void:
    var t: float = clampf(delta * LERP_SPEED, 0.0, 1.0)
    # Zoom snaps rather than interpolating: an in-between zoom would render the
    # whole scene at a fractional texel scale.
    if not is_equal_approx(zoom.x, _target_zoom):
        zoom = Vector2.ONE * _target_zoom
    if global_position.distance_to(_target_position) > 0.5:
        global_position = global_position.lerp(_target_position, t)
    else:
        global_position = _target_position
    # Whole-pixel camera position, so the tile grid never lands on a half pixel.
    global_position = global_position.round()

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
