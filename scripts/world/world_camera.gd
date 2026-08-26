class_name WorldCamera
extends Camera2D
## World-map camera: pointer-anchored zoom, drag/keyboard pan, and focus moves.
##
## Zoom interpolates toward discrete pixel-friendly stops rather than snapping,
## but always settles exactly on a stop so the map renders at an integer texel
## scale (see docs/WORLD_MAP_AND_ZOOM.md).

signal zoom_changed(zoom: float)
signal view_changed()

const ZOOM_STOPS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
const ZOOM_LERP_SPEED := 12.0
const PAN_LERP_SPEED := 14.0
const KEY_PAN_SPEED := 700.0
## Latitude beyond +/-84 is mostly projection stretch; keep it out of frame.
const VERTICAL_MARGIN := 0.06

var zoom_index := 0
var _target_zoom := 1.0
var _target_position := Vector2.ZERO
## Screen point held fixed while zooming, so the map grows around the cursor.
var _zoom_anchor := Vector2.ZERO
var _anchor_to_cursor := true
var _panning := false
var _focusing := false

func _ready() -> void:
    position_smoothing_enabled = false
    zoom_index = ZOOM_STOPS.find(zoom.x)
    if zoom_index < 0:
        zoom_index = 1
    _target_zoom = ZOOM_STOPS[zoom_index]
    zoom = Vector2.ONE * _target_zoom
    _target_position = global_position
    _zoom_anchor = get_viewport_rect().size * 0.5

func current_zoom() -> float:
    return zoom.x

func target_zoom() -> float:
    return _target_zoom

func is_settled() -> bool:
    return absf(zoom.x - _target_zoom) < 0.0005 and global_position.distance_to(_target_position) < 0.5

func screen_to_world(screen_pos: Vector2) -> Vector2:
    return unproject(global_position, zoom.x, get_viewport_rect().size, screen_pos)

func world_to_screen(world_pos: Vector2) -> Vector2:
    return project(global_position, zoom.x, get_viewport_rect().size, world_pos)

# The pointer-anchored zoom maths is kept static and free of node state so the
# "airport stays under the cursor" promise can be tested directly.

static func unproject(camera_pos: Vector2, zoom_level: float, viewport_size: Vector2, screen_pos: Vector2) -> Vector2:
    return camera_pos + (screen_pos - viewport_size * 0.5) / maxf(zoom_level, 0.0001)

static func project(camera_pos: Vector2, zoom_level: float, viewport_size: Vector2, world_pos: Vector2) -> Vector2:
    return (world_pos - camera_pos) * zoom_level + viewport_size * 0.5

## Camera position that keeps `world_pos` pinned under `screen_anchor` at a
## given zoom. Both the wheel zoom and the airport focus use this, which is why
## neither of them drifts off target.
static func anchored_position(world_pos: Vector2, zoom_level: float, viewport_size: Vector2, screen_anchor: Vector2) -> Vector2:
    return world_pos - (screen_anchor - viewport_size * 0.5) / maxf(zoom_level, 0.0001)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var button := event as InputEventMouseButton
        if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
            step_zoom(1, button.position)
            get_viewport().set_input_as_handled()
        elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
            step_zoom(-1, button.position)
            get_viewport().set_input_as_handled()
        elif button.button_index == MOUSE_BUTTON_MIDDLE or button.button_index == MOUSE_BUTTON_RIGHT:
            _panning = button.pressed
            if _panning:
                _focusing = false
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _panning:
        var motion := event as InputEventMouseMotion
        _target_position -= motion.relative / zoom
        global_position = _target_position
        _clamp_target()
        _panning_moved()
        get_viewport().set_input_as_handled()

func _panning_moved() -> void:
    global_position = _target_position
    view_changed.emit()

func step_zoom(direction: int, anchor: Vector2 = Vector2(-1, -1)) -> void:
    var next := clampi(zoom_index + direction, 0, ZOOM_STOPS.size() - 1)
    if next == zoom_index:
        return
    zoom_index = next
    _target_zoom = ZOOM_STOPS[zoom_index]
    _zoom_anchor = anchor if anchor.x >= 0.0 else get_viewport_rect().size * 0.5
    _anchor_to_cursor = true
    _focusing = false
    zoom_changed.emit(_target_zoom)

## Move the view to a world position at a given zoom stop. When `screen_anchor`
## is supplied the target keeps that exact screen position throughout the move,
## which is what makes the airport zoom feel continuous instead of a cut.
func focus_on(world_pos: Vector2, stop_index: int, screen_anchor: Vector2 = Vector2(-1, -1)) -> void:
    zoom_index = clampi(stop_index, 0, ZOOM_STOPS.size() - 1)
    _target_zoom = ZOOM_STOPS[zoom_index]
    _anchor_to_cursor = false
    _focusing = true
    if screen_anchor.x >= 0.0:
        _zoom_anchor = screen_anchor
        # Solve for the camera position that puts world_pos under the anchor.
        _target_position = anchored_position(world_pos, _target_zoom, get_viewport_rect().size, screen_anchor)
    else:
        _zoom_anchor = get_viewport_rect().size * 0.5
        _target_position = world_pos
    _clamp_target()
    zoom_changed.emit(_target_zoom)

func _process(delta: float) -> void:
    var changed := false

    if absf(zoom.x - _target_zoom) > 0.0005:
        var anchor := _zoom_anchor
        if _anchor_to_cursor:
            anchor = get_viewport().get_mouse_position()
        var before := screen_to_world(anchor)
        var next_zoom := lerpf(zoom.x, _target_zoom, clampf(delta * ZOOM_LERP_SPEED, 0.0, 1.0))
        if absf(next_zoom - _target_zoom) < 0.0025:
            next_zoom = _target_zoom
        zoom = Vector2.ONE * next_zoom
        if not _focusing:
            # Hold the anchor point still, so the map expands around the cursor.
            var after := screen_to_world(anchor)
            _target_position += before - after
            global_position = _target_position
        changed = true

    if _focusing or global_position.distance_to(_target_position) > 0.5:
        global_position = global_position.lerp(_target_position, clampf(delta * PAN_LERP_SPEED, 0.0, 1.0))
        if global_position.distance_to(_target_position) < 0.5:
            global_position = _target_position
            _focusing = false
        changed = true

    var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if pan != Vector2.ZERO:
        _focusing = false
        _target_position += pan * KEY_PAN_SPEED * delta / zoom.x
        global_position = _target_position
        changed = true

    _clamp_target()
    if changed:
        view_changed.emit()

## Vertical clamping only: the world wraps horizontally, so lateral panning is
## unbounded and the map view repeats the texture instead.
##
## The target is clamped against the zoom it is heading for, not the zoom it is
## leaving. Clamping a zoom-in against the old, wider view would drag the target
## back toward the equator and the focus would never arrive.
func _clamp_target() -> void:
    _target_position.y = _clamped_y(_target_position.y, _target_zoom)
    global_position.y = _clamped_y(global_position.y, zoom.y)

func _clamped_y(y: float, zoom_level: float) -> float:
    var world_height := WorldProjection.WORLD_SIZE.y
    var half_height := get_viewport_rect().size.y * 0.5 / maxf(zoom_level, 0.0001)
    var top := -world_height * VERTICAL_MARGIN
    var bottom := world_height * (1.0 + VERTICAL_MARGIN)
    if half_height * 2.0 >= bottom - top:
        return world_height * 0.5
    return clampf(y, top + half_height, bottom - half_height)
