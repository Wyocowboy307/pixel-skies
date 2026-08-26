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
    "regional": "world/marker_regional.png",
    "major": "world/marker_major.png",
    "selected": "world/marker_selected.png",
    "dot": "world/marker_dot.png",
}

## Heading change (radians per second of wall time) beyond which a flight is
## drawn from its banked strip instead of the level one.
const BANK_RATE_THRESHOLD := 0.015
## Eastward cloud drift in world units per minute — weather, not traffic.
const CLOUD_DRIFT_PER_MINUTE := 3.0
const CLOUD_MIN_ZOOM := 1.0

var _sprites: Dictionary = {}
var _font: Font

## leg id -> [heading_radians, ticks_msec], pruned as flights settle. Only the
## rate matters, so presentation state never touches the simulation.
var _prev_heading: Dictionary = {}
## family_id|bank -> banked map strip (or null when the family ships none).
var _bank_strips: Dictionary = {}

## Fixed, seeded cloud field: {world: Vector2, kind: int}. Drift is added at
## draw time so the seeds themselves never move.
var _cloud_seeds: Array[Dictionary] = []
var _cloud_sprites: Array[Texture2D] = []
var _cloud_drift := 0.0

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
    _font = load(AssetPaths.resolve_file("ui/font5x7.fnt"))
    for key: String in MARKER_SPRITES:
        var texture: Texture2D = AssetPaths.load_texture(String(MARKER_SPRITES[key]))
        if texture != null:
            _sprites[key] = texture
    for index in range(3):
        var cloud: Texture2D = AssetPaths.load_texture("world/cloud_%d.png" % index)
        if cloud != null:
            _cloud_sprites.append(cloud)

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
    _seed_clouds()

## Fixed cloud positions, seeded around the airports the player actually looks
## at rather than scattered over empty ocean. The same seed always produces the
## same sky, so captures are reproducible.
func _seed_clouds() -> void:
    _cloud_seeds.clear()
    if _cloud_sprites.is_empty() or db == null:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 0x5049_5853
    var airport_ids: Array = db.airports.keys()
    airport_ids.sort()
    var index := 0
    for airport_id: String in airport_ids:
        var airport: Dictionary = db.airports[airport_id]
        for i in range(3):
            var lat: float = float(airport["lat"]) + rng.randf_range(-3.5, 3.5)
            var lon: float = float(airport["lon"]) + rng.randf_range(-5.0, 5.0)
            _cloud_seeds.append({
                "world": WorldProjection.to_world(clampf(lat, -80.0, 80.0), lon),
                "kind": index % _cloud_sprites.size(),
            })
            index += 1
            if _cloud_seeds.size() >= 9:
                return

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
    _cloud_drift = fposmod(
        _cloud_drift + delta * CLOUD_DRIFT_PER_MINUTE / 60.0, WorldProjection.WORLD_SIZE.x)
    if sim != null and not sim.state.active_flights().is_empty():
        queue_redraw()
    elif _clouds_visible():
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
    # Clouds sit above the terrain and its route trails but below every marker,
    # label and aircraft: weather never hides information.
    _draw_clouds()
    var visible: Array[Dictionary] = _visible_airports()
    _obstacles.clear()
    for entry: Dictionary in visible:
        _draw_marker(entry)
    for entry: Dictionary in _label_order(visible):
        _draw_label(entry)
    _draw_flights()

# ---------------------------------------------------------------------------
# Clouds
# ---------------------------------------------------------------------------

func _clouds_visible() -> bool:
    return not _cloud_seeds.is_empty() and camera != null \
        and camera.current_zoom() >= CLOUD_MIN_ZOOM

## A drifting cloud field between the terrain and the traffic. Far out the map
## is an atlas, not a sky, so clouds only appear once zoomed to regional level.
func _draw_clouds() -> void:
    if not _clouds_visible():
        return
    var scale: int = _map_pixel_scale()
    for puff: Dictionary in _cloud_seeds:
        var texture: Texture2D = _cloud_sprites[int(puff["kind"])]
        var base: Vector2 = puff["world"]
        var world := Vector2(
            fposmod(base.x + _cloud_drift, WorldProjection.WORLD_SIZE.x), base.y)
        var at: Vector2 = _snap(camera.world_to_screen(_nearest_copy(world)))
        var drawn: Vector2 = texture.get_size() * float(scale)
        var origin: Vector2 = _snap(at - drawn * 0.5)
        if origin.x > size.x or origin.y > size.y \
                or origin.x + drawn.x < 0.0 or origin.y + drawn.y < 0.0:
            continue
        draw_texture_rect(texture, Rect2(origin, drawn), false)

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
        # The network is white against the saturated ocean — the "that is my
        # airline" read the whole map exists to deliver.
        var colour: Color = _colour("white") if active else Color(_colour("white"), 0.75)
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
    var active_ids: Dictionary = {}
    for leg: FlightLeg in sim.state.active_flights():
        active_ids[leg.id] = true
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
        # Livery and bank together: the player's paint scheme on the banked
        # frames, so a turning aircraft stays their aircraft.
        var strip: Texture2D = LiverySprites.map_strip(plane, _bank_of(leg.id, heading))
        AircraftSprites.draw_frame(self, strip, at, heading, scale)
        # Only the selected aircraft gets a label; labelling every bystander
        # piled tags on top of the airport names near a hub.
        if leg.aircraft_id == selected_aircraft_id:
            _callsign_chip(font, plane, leg, at, now, scale)
    _prune_headings(active_ids)

# ---------------------------------------------------------------------------
# Banking
# ---------------------------------------------------------------------------

## Level or banked map strip. A turning aircraft dips a wing: pure presentation,
## chosen from the heading rate between two drawn frames.
func _strip_for(family_id: String, bank: int) -> Texture2D:
    if bank == 0:
        return AircraftSprites.map_strip(family_id)
    var key: String = "%s|%d" % [family_id, bank]
    if not _bank_strips.has(key):
        var family_key: String = family_id.replace("ac_", "")
        var suffix: String = "bankl" if bank < 0 else "bankr"
        _bank_strips[key] = AssetPaths.load_texture(
            "aircraft/%s/%s_map_%s.png" % [family_key, family_key, suffix])
    var strip: Texture2D = _bank_strips[key]
    return strip if strip != null else AircraftSprites.map_strip(family_id)

## -1 banking left, 1 banking right, 0 level, from the wall-clock heading rate.
func _bank_of(leg_id: String, heading: float) -> int:
    var ticks: int = Time.get_ticks_msec()
    var previous: Array = _prev_heading.get(leg_id, [])
    _prev_heading[leg_id] = [heading, ticks]
    if previous.is_empty():
        return 0
    var dt: float = float(ticks - int(previous[1])) / 1000.0
    if dt <= 0.0 or dt > 1.0:
        return 0
    var rate: float = angle_difference(float(previous[0]), heading) / dt
    if absf(rate) < BANK_RATE_THRESHOLD:
        return 0
    # Heading increases clockwise on screen, so a positive rate is a right turn.
    return 1 if rate > 0.0 else -1

func _prune_headings(active_ids: Dictionary) -> void:
    for leg_id: String in _prev_heading.keys():
        if not active_ids.has(leg_id):
            _prev_heading.erase(leg_id)

## The remaining route of the selected flight, so "where is it going" is
## answerable without opening a panel. A solid orange trail with white dashes
## running along it, so the watched route pops against every terrain.
func _draw_track(leg: FlightLeg, scale: int) -> void:
    var origin: Dictionary = db.airports.get(leg.origin_id, {})
    var destination: Dictionary = db.airports.get(leg.destination_id, {})
    if origin.is_empty() or destination.is_empty():
        return
    var points: PackedVector2Array = _route_points(origin, destination)
    var orange: Color = _colour("accent_orange")
    var white: Color = _colour("white")
    var travelled := 0
    for i in range(points.size() - 1):
        var from: Vector2 = points[i]
        var to: Vector2 = points[i + 1]
        var steps: int = maxi(1, int(from.distance_to(to)))
        for step in range(steps):
            travelled += 1
            var at: Vector2 = _snap(from.lerp(to, float(step) / float(steps)))
            var dashed: bool = (travelled / 3) % 4 == 0
            draw_rect(Rect2(at, Vector2.ONE * float(scale)), white if dashed else orange)

# ---------------------------------------------------------------------------
# Callsign tags
# ---------------------------------------------------------------------------

## The selected flight wears a navy chip: who it is on top, where it is going
## and how long is left underneath, with a little pointer down at the sprite.
func _callsign_chip(font: Font, plane: AircraftInstance, leg: FlightLeg,
        at: Vector2, now: float, scale: int) -> void:
    var name_line: String = plane.registration
    if not plane.nickname.is_empty():
        name_line = "%s  %s" % [plane.nickname.to_upper(), plane.registration]
    var destination: Dictionary = db.airports.get(leg.destination_id, {})
    var eta_line: String = "→ %s · %s" % [String(destination.get("code", "")),
        UiTheme.duration(leg.seconds_remaining(now))]

    var name_width: float = font.get_string_size(
        name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
    var eta_width: float = font.get_string_size(
        eta_line, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
    var box_size := Vector2(maxf(name_width, eta_width) + 10.0, 23.0)
    var gap: float = 10.0 * float(scale)
    var box_origin: Vector2 = _snap(at + Vector2(-box_size.x * 0.5, -gap - box_size.y - 3.0))
    box_origin.x = clampf(box_origin.x, 2.0, size.x - box_size.x - 2.0)
    box_origin.y = maxf(box_origin.y, SAFE_AREA_TOP)

    # A luggage tag, not telemetry: warm yellow card, navy text, punched hole.
    draw_rect(Rect2(box_origin - Vector2.ONE, box_size + Vector2(2.0, 2.0)),
        _colour("outline"))
    draw_rect(Rect2(box_origin, box_size), _colour("accent_yellow"))
    draw_rect(Rect2(box_origin, Vector2(box_size.x, 1.0)), _colour("card_hi"))
    draw_rect(Rect2(box_origin + Vector2(2.0, 2.0), Vector2(2.0, 2.0)), _colour("outline"))
    var notch_x: float = clampf(at.x - 2.0, box_origin.x + 2.0, box_origin.x + box_size.x - 6.0)
    draw_rect(Rect2(_snap(Vector2(notch_x, box_origin.y + box_size.y + 1.0)),
        Vector2(4.0, 2.0)), _colour("outline"))
    draw_rect(Rect2(_snap(Vector2(notch_x + 1.0, box_origin.y + box_size.y + 3.0)),
        Vector2(2.0, 1.0)), _colour("outline"))

    var text_at: Vector2 = _snap(box_origin + Vector2(7.0, 9.0))
    draw_string(font, text_at, name_line, HORIZONTAL_ALIGNMENT_LEFT, -1,
        LABEL_FONT_SIZE, _colour("navy_deep"))
    draw_string(font, text_at + Vector2(0.0, 10.0), eta_line, HORIZONTAL_ALIGNMENT_LEFT, -1,
        LABEL_FONT_SIZE, _colour("btn_blue_lo"))

## Every other on-screen flight gets its registration, small and shadowed, once
## the player is close enough for it to mean something.
func _registration_tag(font: Font, plane: AircraftInstance, at: Vector2, scale: int) -> void:
    var text: String = plane.registration
    var width: float = font.get_string_size(
        text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
    var origin: Vector2 = _snap(at + Vector2(-width * 0.5, -8.0 * float(scale) - 3.0))
    origin.y = maxf(origin.y, SAFE_AREA_TOP)
    draw_string(font, origin + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
        LABEL_FONT_SIZE, _colour("outline"))
    draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
        LABEL_FONT_SIZE, _colour("white"))

## World position of an aircraft in flight, for the follow camera.
func aircraft_world_position(aircraft_id: String) -> Vector2:
    if sim == null:
        return Vector2.ZERO
    var leg: FlightLeg = sim.flight_for_aircraft(aircraft_id)
    if leg == null:
        return Vector2.ZERO
    var place: Dictionary = sim.flights.position_of(leg, sim.now())
    return WorldProjection.to_world(float(place["lat"]), float(place["lon"]))
