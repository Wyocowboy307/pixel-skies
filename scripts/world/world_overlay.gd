class_name WorldOverlay
extends Control
## Screen-space overlay for everything drawn on top of the map: routes, airport
## markers, labels and (later) aircraft.
##
## Markers are drawn, not instantiated as Control nodes, so marker count never
## costs a node per city (docs/WORLD_MAP_AND_ZOOM.md, "Performance"). Drawing in
## screen space also keeps marker and line thickness constant while zooming.

signal airport_clicked(airport_id: String)
signal aircraft_clicked(aircraft_id: String)
signal aircraft_activated(aircraft_id: String)
signal airport_activated(airport_id: String)
signal background_clicked()

const ROUTE_SAMPLES := 32
const CLICK_RADIUS := 10.0
const DOUBLE_CLICK_SECONDS := 0.35
const LABEL_FONT_SIZE := 7
## Labels never intrude under the top bar.
const SAFE_AREA_TOP := 20.0

const MARKER_SPRITES := {
    "regional": "res://assets/art/world/marker_regional.png",
    "major": "res://assets/art/world/marker_major.png",
    "selected": "res://assets/art/world/marker_selected.png",
    "dot": "res://assets/art/world/marker_dot.png",
}

var _sprites: Dictionary = {}
var _font: Font

var db: GameDB
var camera: WorldCamera
var sim: Simulation

var selected_aircraft_id := ""
## Aircraft screen positions computed this frame, reused for picking.
var _aircraft_screen: Dictionary = {}

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
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = 10
    _font = load("res://assets/art/ui/font5x7.fnt")
    for key: String in MARKER_SPRITES:
        var path: String = String(MARKER_SPRITES[key])
        if ResourceLoader.exists(path):
            _sprites[key] = load(path)

func _colour(key: String) -> Color:
    return PixelPalette.get_colour(key)

## Markers and labels are drawn on whole pixels. A marker at a fractional
## position would be resampled by the integer-scaled viewport and lose its
## hard edges.
func _snap(point: Vector2) -> Vector2:
    return Vector2(roundf(point.x), roundf(point.y))

func bind(database: GameDB, world_camera: WorldCamera, simulation: Simulation = null) -> void:
    db = database
    camera = world_camera
    sim = simulation
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
    if sim != null and not sim.state.active_flights().is_empty():
        queue_redraw()
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

func _aircraft_at(screen_pos: Vector2) -> String:
    var best := ""
    var best_distance := 12.0
    for aircraft_id: String in _aircraft_screen:
        var distance: float = (_aircraft_screen[aircraft_id] as Vector2).distance_to(screen_pos)
        if distance < best_distance:
            best_distance = distance
            best = aircraft_id
    return best

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
    var aircraft_hit: String = _aircraft_at(button.position)
    if not aircraft_hit.is_empty():
        var repeat: bool = aircraft_hit == selected_aircraft_id
        selected_aircraft_id = aircraft_hit
        get_viewport().set_input_as_handled()
        queue_redraw()
        # Click selects; clicking the selected aircraft again opens its detail
        # view (docs/UI_UX.md, "Plane selection").
        if repeat:
            aircraft_activated.emit(aircraft_hit)
        else:
            aircraft_clicked.emit(aircraft_hit)
        return

    var hit: String = _airport_at(button.position)
    if hit.is_empty():
        selected_aircraft_id = ""
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
    _draw_flights()

func _visible_airports() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var margin := 24.0
    for airport_id: String in db.airports:
        var pos: Vector2 = _snap(airport_screen_position(airport_id))
        if pos.x < -margin or pos.y < -margin or pos.x > size.x + margin or pos.y > size.y + margin:
            continue
        var airport: Dictionary = db.airports[airport_id]
        out.append({
            "id": airport_id,
            "airport": airport,
            "pos": pos,
            "major": String(airport["tier"]) == "major",
        })
    return out

## Selected, hovered and major airports claim label space first, so the airport
## the player is looking at never loses its name to a neighbour.
func _label_order(visible: Array[Dictionary]) -> Array[Dictionary]:
    var priority: Array[Dictionary] = []
    var rest: Array[Dictionary] = []
    for entry: Dictionary in visible:
        var id: String = String(entry["id"])
        if id == selected_airport_id or id == hovered_airport_id or bool(entry["major"]):
            priority.append(entry)
        else:
            rest.append(entry)
    return priority + rest

## Route lines are stepped along whole pixels rather than drawn as a smooth
## polyline, so they read as a dotted pixel trail instead of an aliased curve.
func _draw_routes() -> void:
    for pair: Array in routes:
        var a: Dictionary = db.airports[String(pair[0])]
        var b: Dictionary = db.airports[String(pair[1])]
        var active: bool = selected_airport_id == String(pair[0]) or selected_airport_id == String(pair[1])
        var colour: Color = _colour("ui_border_light") if active else _colour("ui_border")
        var points: PackedVector2Array = _route_points(a, b)
        var travelled := 0
        for i in range(points.size() - 1):
            var from: Vector2 = points[i]
            var to: Vector2 = points[i + 1]
            var steps: int = maxi(1, int(from.distance_to(to)))
            for step in range(steps):
                travelled += 1
                # Dashed: three pixels on, three off.
                if (travelled / 3) % 2 == 1 and not active:
                    continue
                var at: Vector2 = _snap(from.lerp(to, float(step) / float(steps)))
                draw_rect(Rect2(at, Vector2.ONE), colour)

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

func _blit(key: String, centre: Vector2, modulate: Color = Color.WHITE) -> Vector2:
    var texture: Texture2D = _sprites.get(key, null)
    if texture == null:
        return Vector2.ZERO
    var half: Vector2 = (texture.get_size() * 0.5).floor()
    draw_texture(texture, _snap(centre - half), modulate)
    return texture.get_size()

func _draw_marker(entry: Dictionary) -> void:
    var pos: Vector2 = entry["pos"]
    var id: String = String(entry["id"])
    var selected: bool = id == selected_airport_id
    var hovered: bool = id == hovered_airport_id

    # Far out, an airport is the three-pixel marker the zoom doc calls for.
    var far: bool = camera.current_zoom() <= 0.25 and not (selected or hovered)
    var key: String = "dot" if far else ("major" if bool(entry["major"]) else "regional")
    var tint: Color = _colour("white") if hovered else Color.WHITE
    var used: Vector2 = _blit(key, pos, tint)

    if selected:
        # Ring pulses between two palette colours rather than fading alpha,
        # which would produce off-palette pixels.
        var on: bool = fmod(_pulse, 1.0) < 0.6
        _blit("selected", pos, _colour("white") if on else _colour("accent_orange"))
        used = Vector2(13, 13)

    var claim: Vector2 = used if used != Vector2.ZERO else Vector2(7, 7)
    _obstacles.append(Rect2(pos - claim * 0.5 - Vector2.ONE, claim + Vector2(2, 2)))

func _draw_label(entry: Dictionary) -> void:
    var id: String = String(entry["id"])
    var airport: Dictionary = entry["airport"]
    var pos: Vector2 = entry["pos"]
    var emphasised: bool = id == selected_airport_id or id == hovered_airport_id
    var zoom: float = camera.current_zoom()
    if not (emphasised or bool(entry["major"]) or zoom >= 0.5):
        return

    var text: String = String(airport["code"])
    if zoom >= 2.0 or emphasised:
        text = "%s %s" % [String(airport["code"]), String(airport["city"])]

    var extents: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
    var gap := 7.0
    var candidates: Array[Vector2] = [
        pos + Vector2(gap, 3.0),
        pos + Vector2(-gap - extents.x, 3.0),
        pos + Vector2(-roundf(extents.x * 0.5), -gap),
        pos + Vector2(-roundf(extents.x * 0.5), gap + 7.0),
    ]
    for index in range(candidates.size()):
        var origin: Vector2 = candidates[index]
        var snapped: Vector2 = _snap(origin)
        var claim := Rect2(snapped + Vector2(-1.0, -LABEL_FONT_SIZE), extents + Vector2(2.0, 3.0))
        if claim.position.y < SAFE_AREA_TOP:
            continue
        # The airport the player just selected always gets its name, even in a
        # crowd: on the last candidate it is placed regardless of collision.
        var forced: bool = emphasised and index == candidates.size() - 1
        if _collides(claim) and not forced:
            continue
        _obstacles.append(claim)
        # One-pixel drop shadow keeps the label readable over any terrain.
        draw_string(_font, snapped + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
            LABEL_FONT_SIZE, _colour("outline"))
        draw_string(_font, snapped, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
            LABEL_FONT_SIZE, _colour("white") if emphasised else _colour("text"))
        return

func _collides(rect: Rect2) -> bool:
    for taken: Rect2 in _obstacles:
        if taken.intersects(rect):
            return true
    return false


# ---------------------------------------------------------------------------
# Live aircraft
# ---------------------------------------------------------------------------

## Sprite scale follows the map's own texel scale, so an aircraft is never drawn
## at a finer pixel density than the terrain beneath it.
func _map_pixel_scale() -> int:
    var tier: int = WorldLod.tier_for_zoom(minf(camera.current_zoom(), camera.target_zoom()))
    return maxi(1, int(roundf(WorldLod.world_scale(tier) * camera.current_zoom())))

func _draw_flights() -> void:
    _aircraft_screen.clear()
    if sim == null:
        return
    var now: float = sim.now()
    var scale: int = _map_pixel_scale()
    var font: Font = _font
    for leg: FlightLeg in sim.state.active_flights():
        var place: Dictionary = sim.flights.position_of(leg, now)
        var world: Vector2 = _nearest_copy(
            WorldProjection.to_world(float(place["lat"]), float(place["lon"])))
        var at: Vector2 = _snap(camera.world_to_screen(world))
        if at.x < -32.0 or at.y < -32.0 or at.x > size.x + 32.0 or at.y > size.y + 32.0:
            continue
        _aircraft_screen[leg.aircraft_id] = at

        var plane: AircraftInstance = sim.state.aircraft.get(leg.aircraft_id, null)
        if plane == null:
            continue
        var heading: float = AircraftSprites.bearing_to_screen(float(place["bearing"]))

        if camera.current_zoom() <= 0.5:
            # Far out an aircraft is a directional pixel, not a sprite
            # (docs/WORLD_MAP_AND_ZOOM.md, "Aircraft rendering by zoom").
            draw_rect(Rect2(at - Vector2.ONE, Vector2(3, 3)), _colour("outline"))
            draw_rect(Rect2(at, Vector2.ONE), _colour("accent_orange_light"))
            continue

        if leg.aircraft_id == selected_aircraft_id:
            _draw_track(leg, scale)
        AircraftSprites.draw_map(self, plane.family_id, at, heading, scale)
        if leg.aircraft_id == selected_aircraft_id:
            _flight_tag(font, plane, leg, at, now, scale)

## The remaining route of the selected flight, so "where is it going" is
## answerable without opening a panel.
func _draw_track(leg: FlightLeg, scale: int) -> void:
    var origin: Dictionary = db.airports.get(leg.origin_id, {})
    var destination: Dictionary = db.airports.get(leg.destination_id, {})
    if origin.is_empty() or destination.is_empty():
        return
    var points: PackedVector2Array = _route_points(origin, destination)
    var travelled := 0
    for i in range(points.size() - 1):
        var from: Vector2 = points[i]
        var to: Vector2 = points[i + 1]
        var steps: int = maxi(1, int(from.distance_to(to)))
        for step in range(steps):
            travelled += 1
            if (travelled / 2) % 2 == 1:
                continue
            var at: Vector2 = _snap(from.lerp(to, float(step) / float(steps)))
            draw_rect(Rect2(at, Vector2.ONE * float(scale)), _colour("accent_orange"))

func _flight_tag(font: Font, plane: AircraftInstance, leg: FlightLeg,
        at: Vector2, now: float, scale: int) -> void:
    var destination: Dictionary = db.airports.get(leg.destination_id, {})
    var text: String = "%s → %s · %s" % [
        plane.display_name(), String(destination.get("code", "")),
        UiTheme.duration(leg.seconds_remaining(now))]
    var origin: Vector2 = _snap(at + Vector2(9.0 * float(scale), -4.0))
    draw_string(font, origin + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
        LABEL_FONT_SIZE, _colour("outline"))
    draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
        LABEL_FONT_SIZE, _colour("accent_orange_light"))

## World position of an aircraft in flight, for the follow camera.
func aircraft_world_position(aircraft_id: String) -> Vector2:
    if sim == null:
        return Vector2.ZERO
    var leg: FlightLeg = sim.flight_for_aircraft(aircraft_id)
    if leg == null:
        return Vector2.ZERO
    var place: Dictionary = sim.flights.position_of(leg, sim.now())
    return WorldProjection.to_world(float(place["lat"]), float(place["lon"]))
