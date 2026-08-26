class_name WorldOverlay
extends Control
## Screen-space overlay for everything drawn on top of the map: routes, airport
## markers, labels and (later) aircraft.
##
## Markers are drawn, not instantiated as Control nodes, so marker count never
## costs a node per city (docs/WORLD_MAP_AND_ZOOM.md, "Performance"). Drawing in
## screen space also keeps marker and line thickness constant while zooming.

signal airport_clicked(airport_id: String)
signal airport_activated(airport_id: String)
signal background_clicked()

const ROUTE_SAMPLES := 32
const ROUTE_COLOR := Color("#4d7f96")
const ROUTE_COLOR_ACTIVE := Color("#9fd8ea")
const MARKER_REGIONAL := Color("#f4e2a1")
const MARKER_MAJOR := Color("#f3ad63")
const MARKER_RING := Color("#0c1c28")
const LABEL_COLOR := Color("#e8f1f4")
const LABEL_SHADOW := Color("#08131b")
const HOVER_COLOR := Color("#ffffff")
const CLICK_RADIUS := 18.0
const DOUBLE_CLICK_SECONDS := 0.35
const LABEL_FONT_SIZE := 13
## Labels never intrude under the top bar.
const SAFE_AREA_TOP := 58.0

var db: GameDB
var camera: WorldCamera

var selected_airport_id := ""
var hovered_airport_id := ""
var routes: Array[Array] = []

## Screen rects claimed by markers and labels this frame, used to declutter.
var _obstacles: Array[Rect2] = []
var _last_click_id := ""
var _last_click_time := 0.0
var _pulse := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    z_index = 10

func bind(database: GameDB, world_camera: WorldCamera) -> void:
    db = database
    camera = world_camera
    camera.view_changed.connect(queue_redraw)
    _rebuild_routes()

func _rebuild_routes() -> void:
    # Vertical-slice network. Milestone 3 replaces this with the airline's real
    # served routes rather than every pair of unlocked airports.
    routes = [
        ["apt_bzn", "apt_bil"],
        ["apt_bzn", "apt_den"],
        ["apt_bil", "apt_den"],
    ]

func _process(delta: float) -> void:
    _pulse = fposmod(_pulse + delta, TAU)
    var previous := hovered_airport_id
    hovered_airport_id = _airport_at(get_viewport().get_mouse_position())
    if previous != hovered_airport_id:
        queue_redraw()
    elif selected_airport_id != "":
        queue_redraw()

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

## World X of `world_pos` shifted into the wrapped copy nearest the camera, so
## markers and routes stay attached to the map copy the player is looking at.
func _nearest_copy(world_pos: Vector2) -> Vector2:
    if camera == null:
        return world_pos
    var width: float = WorldProjection.WORLD_SIZE.x
    var offset: float = roundf((camera.global_position.x - world_pos.x) / width)
    return Vector2(world_pos.x + offset * width, world_pos.y)

func airport_screen_position(airport_id: String) -> Vector2:
    var airport: Dictionary = db.airports[airport_id]
    var world: Vector2 = _nearest_copy(
        WorldProjection.to_world(float(airport["lat"]), float(airport["lon"])))
    return camera.world_to_screen(world)

func _airport_at(screen_pos: Vector2) -> String:
    if db == null or camera == null:
        return ""
    var best := ""
    var best_distance := CLICK_RADIUS
    for airport_id: String in db.airports:
        var distance: float = airport_screen_position(airport_id).distance_to(screen_pos)
        if distance < best_distance:
            best_distance = distance
            best = airport_id
    return best

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var button := event as InputEventMouseButton
    if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
        return
    var hit: String = _airport_at(button.position)
    if hit.is_empty():
        selected_airport_id = ""
        background_clicked.emit()
        queue_redraw()
        return

    var now: float = Time.get_ticks_msec() / 1000.0
    var is_double: bool = hit == _last_click_id and (now - _last_click_time) < DOUBLE_CLICK_SECONDS
    _last_click_id = hit
    _last_click_time = now
    selected_airport_id = hit
    get_viewport().set_input_as_handled()
    queue_redraw()
    # First click selects and shows the card; second focuses (docs/AIRPORT_SYSTEM.md).
    if is_double:
        airport_activated.emit(hit)
    else:
        airport_clicked.emit(hit)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

## Markers are drawn before any label, and every marker reserves space, so a
## label can never be printed underneath a neighbouring airport's dot.
func _draw() -> void:
    if db == null or camera == null:
        return
    _draw_routes()

    var visible: Array[Dictionary] = _visible_airports()
    _obstacles.clear()
    for entry: Dictionary in visible:
        _draw_marker(entry)

    for entry: Dictionary in _label_order(visible):
        _draw_label(entry)

func _visible_airports() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var margin := 80.0
    for airport_id: String in db.airports:
        var pos: Vector2 = airport_screen_position(airport_id)
        if pos.x < -margin or pos.y < -margin or pos.x > size.x + margin or pos.y > size.y + margin:
            continue
        var airport: Dictionary = db.airports[airport_id]
        var is_major: bool = String(airport["tier"]) == "major"
        out.append({
            "id": airport_id,
            "airport": airport,
            "pos": pos,
            "major": is_major,
            "radius": 5.0 if is_major else 4.0,
        })
    return out

## Selected and hovered airports get first claim on label space, so the airport
## the player is actually looking at never loses its name to a neighbour.
func _label_order(visible: Array[Dictionary]) -> Array[Dictionary]:
    var priority: Array[Dictionary] = []
    var rest: Array[Dictionary] = []
    for entry: Dictionary in visible:
        var id: String = String(entry["id"])
        if id == selected_airport_id or id == hovered_airport_id:
            priority.append(entry)
        elif bool(entry["major"]):
            priority.append(entry)
        else:
            rest.append(entry)
    return priority + rest

func _draw_routes() -> void:
    for pair: Array in routes:
        var a: Dictionary = db.airports[String(pair[0])]
        var b: Dictionary = db.airports[String(pair[1])]
        var points: PackedVector2Array = _route_points(a, b)
        if points.size() < 2:
            continue
        var active: bool = selected_airport_id == String(pair[0]) or selected_airport_id == String(pair[1])
        var color: Color = ROUTE_COLOR_ACTIVE if active else ROUTE_COLOR
        var width: float = 2.0 if active else 1.0
        draw_polyline(points, Color(color, 0.75 if active else 0.45), width)

## Samples the great circle, so a long route bends the way flight actually goes
## rather than cutting a straight line across the projection.
func _route_points(a: Dictionary, b: Dictionary) -> PackedVector2Array:
    var points: PackedVector2Array = []
    var lat1: float = float(a["lat"])
    var lon1: float = float(a["lon"])
    var lat2: float = float(b["lat"])
    var lon2: float = float(b["lon"])
    for i in range(ROUTE_SAMPLES + 1):
        var t: float = float(i) / float(ROUTE_SAMPLES)
        var point: Vector2 = WorldProjection.interpolate_great_circle(lat1, lon1, lat2, lon2, t)
        var world: Vector2 = _nearest_copy(WorldProjection.to_world(point.x, point.y))
        points.append(camera.world_to_screen(world))
    return points

func _draw_marker(entry: Dictionary) -> void:
    var pos: Vector2 = entry["pos"]
    var radius: float = float(entry["radius"])
    var id: String = String(entry["id"])
    var color: Color = MARKER_MAJOR if bool(entry["major"]) else MARKER_REGIONAL
    var selected: bool = id == selected_airport_id
    var hovered: bool = id == hovered_airport_id

    if selected:
        # Pulsing ring reads as "this is the thing you picked" at any zoom.
        var pulse: float = 0.5 + 0.5 * sin(_pulse * 3.0)
        draw_arc(pos, radius + 6.0 + pulse * 3.0, 0.0, TAU, 28, Color(HOVER_COLOR, 0.35 + pulse * 0.3), 1.5)
    if hovered or selected:
        draw_circle(pos, radius + 3.0, Color(color, 0.25))

    draw_circle(pos, radius + 1.5, MARKER_RING)
    draw_circle(pos, radius, HOVER_COLOR if hovered else color)
    if bool(entry["major"]):
        draw_circle(pos, radius - 2.0, MARKER_RING)

    var claim: float = radius + 4.0
    _obstacles.append(Rect2(pos - Vector2(claim, claim), Vector2(claim, claim) * 2.0))

## Label density thins as the world gets small, so a zoomed-out view stays
## readable instead of turning into overlapping text.
func _draw_label(entry: Dictionary) -> void:
    var id: String = String(entry["id"])
    var airport: Dictionary = entry["airport"]
    var pos: Vector2 = entry["pos"]
    var radius: float = float(entry["radius"])
    var emphasised: bool = id == selected_airport_id or id == hovered_airport_id
    var zoom: float = camera.current_zoom()
    if not (emphasised or bool(entry["major"]) or zoom >= 0.5):
        return

    var text: String = String(airport["code"])
    if zoom >= 2.0 or emphasised:
        text = "%s  %s" % [String(airport["code"]), String(airport["city"])]

    var font: Font = ThemeDB.fallback_font
    var extents: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
    var gap: float = radius + 6.0

    # Try each side in turn and take the first placement that is clear; a label
    # crowded out on the right is usually perfectly readable on the left.
    var candidates: Array[Vector2] = [
        pos + Vector2(gap, LABEL_FONT_SIZE * 0.38),
        pos + Vector2(-gap - extents.x, LABEL_FONT_SIZE * 0.38),
        pos + Vector2(-extents.x * 0.5, -gap - 2.0),
        pos + Vector2(-extents.x * 0.5, gap + LABEL_FONT_SIZE),
    ]
    for origin: Vector2 in candidates:
        var claim := Rect2(origin + Vector2(-3.0, -LABEL_FONT_SIZE), extents + Vector2(6.0, 5.0))
        if claim.position.y < SAFE_AREA_TOP:
            continue
        if _collides(claim):
            continue
        _obstacles.append(claim)
        draw_string(font, origin + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_SHADOW)
        draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)
        return

func _collides(rect: Rect2) -> bool:
    for taken: Rect2 in _obstacles:
        if taken.intersects(rect):
            return true
    return false
