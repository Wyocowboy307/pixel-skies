class_name AirportView
extends Node2D
## Top-down airport diorama, built from data-defined layout plus pixel tiles and
## sprites. Nothing here is drawn as a smooth primitive.
##
## Local coordinates are centred on (0,0) and aligned to the 16 px tile grid; the
## world map's geographic space never reaches here
## (docs/TECH_ARCHITECTURE.md, "Airport movement").

signal aircraft_clicked(aircraft_id: String)

const TILE := 16
const TILES := "res://assets/art/airports/tiles/%s.png"
const BUILDINGS := "res://assets/art/airports/buildings/%s.png"
const VEHICLES := "res://assets/art/airports/vehicles/%s.png"

var airport_id := ""
var layout: Dictionary = {}
var airport: Dictionary = {}
var sim: Simulation
var selected_aircraft_id := ""

var _biome := "mountain"
var _tiles: Dictionary = {}
var _sprites: Dictionary = {}
var _scatter: Array[Dictionary] = []
var _prop_phase := 0.0

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_process(true)

func setup(airport_data: Dictionary, layout_data: Dictionary) -> void:
    airport = airport_data
    layout = layout_data
    airport_id = String(airport_data.get("id", ""))
    _biome = String(layout.get("biome", "plains"))
    _build_scatter()
    queue_redraw()

func bind_sim(simulation: Simulation) -> void:
    sim = simulation
    queue_redraw()

func _process(delta: float) -> void:
    _prop_phase = fposmod(_prop_phase + delta * 14.0, TAU)
    if _has_running_aircraft():
        queue_redraw()

func _has_running_aircraft() -> bool:
    if sim == null:
        return false
    for plane: AircraftInstance in sim.state.aircraft_at(airport_id):
        if plane.state != AircraftInstance.State.PARKED:
            return true
    return false

# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

func _tile(name: String) -> Texture2D:
    if not _tiles.has(name):
        var path: String = TILES % name
        _tiles[name] = load(path) if ResourceLoader.exists(path) else null
    return _tiles[name]

func _sprite(path: String) -> Texture2D:
    if not _sprites.has(path):
        _sprites[path] = load(path) if ResourceLoader.exists(path) else null
    return _sprites[path]

func _grass_tile() -> String:
    match _biome:
        "plains": return "grass_plains"
        "highplains": return "grass_highplains"
        _: return "grass_mountain"

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

func _vec(raw: Variant) -> Vector2:
    var array: Array = raw
    if array.size() < 2:
        return Vector2.ZERO
    return Vector2(float(array[0]), float(array[1]))

func _extent() -> Vector2:
    return _vec(layout.get("ground_extent", [768, 432])) * 0.5

func bounds() -> Rect2:
    var extent: Vector2 = _extent()
    return Rect2(-extent, extent * 2.0)

func apron_centre() -> Vector2:
    var apron: Dictionary = layout.get("apron", {})
    if apron.is_empty():
        return Vector2.ZERO
    return _vec(apron.get("centre", [0, 0])) + Vector2(0.0, 40.0)

func stand_transform(stand_id: String) -> Dictionary:
    for entry: Variant in layout.get("stands", []):
        var stand: Dictionary = entry
        if String(stand.get("id", "")) == stand_id:
            return {
                "position": _vec(stand.get("position", [0, 0])),
                "heading": deg_to_rad(float(stand.get("heading", -90.0))),
                "size": String(stand.get("size", "small")),
            }
    return {}

func aircraft_at_point(local_point: Vector2) -> String:
    if sim == null:
        return ""
    for plane: AircraftInstance in sim.state.aircraft_at(airport_id):
        var place: Dictionary = stand_transform(plane.stand_id)
        if place.is_empty():
            continue
        if (place["position"] as Vector2).distance_to(local_point) < 26.0:
            return plane.id
    return ""

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var button := event as InputEventMouseButton
    if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
        return
    var hit: String = aircraft_at_point(get_local_mouse_position())
    if not hit.is_empty():
        selected_aircraft_id = hit
        aircraft_clicked.emit(hit)
        get_viewport().set_input_as_handled()
        queue_redraw()

## Deterministic decoration scatter, seeded from the airport id, so a field
## looks identical every time it is opened.
func _build_scatter() -> void:
    _scatter.clear()
    var index := 0
    for item: Variant in layout.get("decor", []):
        var decor: Dictionary = item
        var centre: Vector2 = _vec(decor.get("position", [0, 0]))
        var size: Vector2 = _vec(decor.get("size", [64, 64]))
        var kind: String = String(decor.get("type", "trees"))
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("%s_decor_%d" % [airport_id, index])
        index += 1
        var density: float = 900.0 if kind == "ridge" else 1500.0
        var count: int = clampi(int(size.x * size.y / density), 4, 90)
        for _i in range(count):
            _scatter.append({
                "kind": kind,
                "at": Vector2(
                    roundf(centre.x + rng.randf_range(-size.x, size.x) * 0.5),
                    roundf(centre.y + rng.randf_range(-size.y, size.y) * 0.5)),
                "size": rng.randi_range(2, 4),
            })

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
    if layout.is_empty():
        return
    _draw_ground()
    _draw_decor()
    for runway: Dictionary in _all_runways():
        _draw_runway(runway)
    _draw_taxiways()
    _draw_apron()
    _draw_stands()
    _draw_buildings()
    _draw_service_vehicles()
    _draw_parked_aircraft()

func _all_runways() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var primary: Dictionary = layout.get("runway", {})
    if not primary.is_empty():
        out.append(primary)
    for extra: Variant in layout.get("secondary_runways", []):
        out.append(extra as Dictionary)
    return out

## Tiling is done by the renderer (draw_texture_rect with tile=true), so a whole
## surface costs one draw call regardless of how many tiles it covers.
func _tiled(name: String, rect: Rect2) -> void:
    var texture: Texture2D = _tile(name)
    if texture != null:
        draw_texture_rect(texture, rect, true)

func _draw_ground() -> void:
    var extent: Vector2 = _extent()
    # Oversized so panning to the edge never reveals the clear colour.
    _tiled(_grass_tile(), Rect2(-extent - Vector2(256, 256), extent * 2.0 + Vector2(512, 512)))

func _draw_decor() -> void:
    var canopy: Color = PixelPalette.get_colour("grass_dark")
    var rock: Color = PixelPalette.get_colour("tundra")
    var crop: Color = PixelPalette.get_colour("scrub")
    var shadow: Color = PixelPalette.get_colour("outline")
    for item: Dictionary in _scatter:
        var at: Vector2 = item["at"]
        var size: float = float(item["size"])
        var kind: String = String(item["kind"])
        var colour: Color = canopy
        if kind == "ridge":
            colour = rock
        elif kind == "fields" or kind == "scrub":
            colour = crop
        # Solid blocks with a one-pixel shadow: no soft circles anywhere.
        draw_rect(Rect2(at + Vector2.ONE, Vector2(size, size)), shadow)
        draw_rect(Rect2(at, Vector2(size, size)), colour)
        draw_rect(Rect2(at, Vector2(maxf(1.0, size - 2.0), 1.0)),
            PixelPalette.get_colour("grass_light"))

func _draw_runway(runway: Dictionary) -> void:
    var start: Vector2 = _vec(runway.get("start", [0, 0]))
    var end: Vector2 = _vec(runway.get("end", [0, 0]))
    var width: float = float(runway.get("width", 32.0))
    var rect := Rect2(Vector2(start.x, start.y - width * 0.5), Vector2(end.x - start.x, width))

    _tiled("asphalt", rect)
    # Edge lines, threshold bars, then the centreline: the reading order that
    # makes a runway instantly different from a taxiway.
    _tiled("runway_edge_top", Rect2(rect.position, Vector2(rect.size.x, TILE)))
    _tiled("runway_edge_bottom", Rect2(Vector2(rect.position.x, rect.end.y - TILE),
        Vector2(rect.size.x, TILE)))
    _tiled("runway_threshold", Rect2(rect.position, Vector2(TILE * 2, rect.size.y)))
    _tiled("runway_threshold", Rect2(Vector2(rect.end.x - TILE * 2, rect.position.y),
        Vector2(TILE * 2, rect.size.y)))
    _tiled("runway_centreline", Rect2(
        Vector2(rect.position.x + TILE * 3, rect.position.y + rect.size.y * 0.5 - TILE * 0.5),
        Vector2(rect.size.x - TILE * 6, TILE)))
    _draw_designations(runway, rect)

func _draw_designations(runway: Dictionary, rect: Rect2) -> void:
    var designations: Array = runway.get("designations", [])
    if designations.size() < 2:
        return
    var font: Font = load("res://assets/art/ui/font5x7.fnt")
    var colour: Color = PixelPalette.get_colour("white")
    var mid_y: float = rect.position.y + rect.size.y * 0.5
    # Painted on the surface, so they read along the direction of travel.
    _rotated_text(font, String(designations[0]),
        Vector2(rect.position.x + TILE * 3, mid_y), -PI * 0.5, colour)
    _rotated_text(font, String(designations[1]),
        Vector2(rect.end.x - TILE * 3, mid_y), PI * 0.5, colour)

func _rotated_text(font: Font, text: String, at: Vector2, angle: float, colour: Color) -> void:
    var extents: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7)
    draw_set_transform(at.round(), angle, Vector2.ONE)
    draw_string(font, Vector2(-roundf(extents.x * 0.5), 3.0), text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 7, colour)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_taxiways() -> void:
    for item: Variant in layout.get("taxiways", []):
        var taxiway: Dictionary = item
        var width: float = float(taxiway.get("width", TILE))
        var points: Array = taxiway.get("points", [])
        for i in range(points.size() - 1):
            var a: Vector2 = _vec(points[i])
            var b: Vector2 = _vec(points[i + 1])
            var rect: Rect2 = _segment_rect(a, b, width)
            _tiled("taxiway", rect)
            # Yellow centreline runs along the segment's long axis.
            if absf(b.x - a.x) >= absf(b.y - a.y):
                _tiled("taxiway_centreline", Rect2(
                    Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 - TILE * 0.5),
                    Vector2(rect.size.x, TILE)))
            else:
                draw_rect(Rect2(
                    Vector2(rect.position.x + rect.size.x * 0.5 - 1.0, rect.position.y),
                    Vector2(1.0, rect.size.y)), PixelPalette.get_colour("accent_yellow"))

## Axis-aligned segments only, which is what the authored layouts use; a
## diagonal taxiway would need a rotated tile set.
func _segment_rect(a: Vector2, b: Vector2, width: float) -> Rect2:
    var half: float = width * 0.5
    var min_point := Vector2(minf(a.x, b.x), minf(a.y, b.y))
    var max_point := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
    return Rect2(min_point - Vector2(half, half),
        (max_point - min_point) + Vector2(width, width))

func _draw_apron() -> void:
    var apron: Dictionary = layout.get("apron", {})
    if apron.is_empty():
        return
    var centre: Vector2 = _vec(apron.get("centre", [0, 0]))
    var size: Vector2 = _vec(apron.get("size", [256, 80]))
    _tiled("apron", Rect2(centre - size * 0.5, size))

## A stand is one marking, drawn once. Tiling the marking texture across the
## stand area repeats the cross every 16 px and turns the apron into a grid of
## crosses instead of a parking position.
func _draw_stands() -> void:
    var font: Font = load("res://assets/art/ui/font5x7.fnt")
    var yellow: Color = PixelPalette.get_colour("accent_yellow")
    for entry: Variant in layout.get("stands", []):
        var stand: Dictionary = entry
        var at: Vector2 = _vec(stand.get("position", [0, 0])).round()
        var span: float = _stand_span(String(stand.get("size", "small")))
        var half: float = roundf(span * 0.5)
        var heading: float = deg_to_rad(float(stand.get("heading", -90.0)))
        var facing := Vector2(cos(heading), sin(heading)).round()
        var across := Vector2(-facing.y, facing.x)

        # Lead-in line running back from the stop bar the way the aircraft taxis.
        var lead_from: Vector2 = at - facing * half
        for step in range(int(half)):
            var pixel: Vector2 = (at - facing * float(step)).round()
            if step % 4 != 3:
                draw_rect(Rect2(pixel, Vector2.ONE), yellow)
        # Stop bar across the nose position.
        var bar_half: float = roundf(half * 0.45)
        draw_rect(Rect2((at + facing * 4.0 - across * bar_half).round(),
            (across.abs() * bar_half * 2.0 + facing.abs() + Vector2(1, 1)).round()), yellow)
        # Corner ticks marking the box the aircraft must sit inside.
        for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
            var origin: Vector2 = (at + corner * half).round()
            draw_rect(Rect2(origin - Vector2(maxf(0.0, corner.x) * 5.0, 0.0), Vector2(5, 1)), yellow)
            draw_rect(Rect2(origin - Vector2(0.0, maxf(0.0, corner.y) * 5.0), Vector2(1, 5)), yellow)

        var label: String = String(stand.get("id", "")).replace("stand_", "S")
        draw_string(font, (at + Vector2(-half + 2.0, -half + 8.0)).round(), label,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 7, yellow)
        var _unused: Vector2 = lead_from

func _stand_span(size_name: String) -> float:
    match size_name:
        "large": return 96.0
        "medium": return 80.0
        _: return 64.0

func _draw_buildings() -> void:
    for entry: Variant in layout.get("buildings", []):
        var building: Dictionary = entry
        _blit_building(String(building.get("sprite", "terminal_1")),
            _vec(building.get("position", [0, 0])))
    # Upgrade slots only appear once the airline has actually built them, which
    # is what makes an upgrade a visible change (docs/AIRPORT_SYSTEM.md).
    if sim == null:
        return
    for entry: Variant in layout.get("upgrade_slots", []):
        var slot: Dictionary = entry
        if _slot_is_built(String(slot.get("visual_change", ""))):
            _blit_building(String(slot.get("sprite", "")), _vec(slot.get("position", [0, 0])))

func _slot_is_built(visual_change: String) -> bool:
    for upgrade_id: String in sim.state.upgrades_at(airport_id):
        var upgrade: Dictionary = sim.db.airport_upgrades.get(upgrade_id, {})
        if String(upgrade.get("visual_change", "")) == visual_change:
            return true
    return false

func _blit_building(sprite_name: String, at: Vector2) -> void:
    if sprite_name.is_empty():
        return
    var texture: Texture2D = _sprite(BUILDINGS % sprite_name)
    if texture == null:
        return
    var size: Vector2 = texture.get_size()
    draw_texture(texture, (at - size * 0.5).round())

func _draw_service_vehicles() -> void:
    for entry: Variant in layout.get("service_points", []):
        var point: Dictionary = entry
        var texture: Texture2D = _sprite(VEHICLES % String(point.get("vehicle", "tug")))
        if texture == null:
            continue
        var at: Vector2 = _vec(point.get("position", [0, 0]))
        draw_texture(texture, (at - texture.get_size() * 0.5).round())

## Aircraft use pre-rendered rotation frames rather than a runtime rotation,
## which would resample the sprite and destroy its hard edges.
func _draw_parked_aircraft() -> void:
    if sim == null:
        return
    var font: Font = load("res://assets/art/ui/font5x7.fnt")
    for plane: AircraftInstance in sim.state.aircraft_at(airport_id):
        var place: Dictionary = stand_transform(plane.stand_id)
        if place.is_empty():
            continue
        var at: Vector2 = place["position"]
        draw_aircraft(plane.family_id, at, float(place["heading"]))

        if plane.id == selected_aircraft_id:
            var box := 30.0
            _selection_bracket(at, box)
        var label: String = plane.display_name()
        var extents: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7)
        var text_at: Vector2 = (at + Vector2(-extents.x * 0.5, 30.0)).round()
        draw_string(font, text_at + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
            PixelPalette.get_colour("outline"))
        draw_string(font, text_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
            PixelPalette.get_colour("text"))

func draw_aircraft(family_id: String, at: Vector2, heading: float) -> void:
    AircraftSprites.draw_ground(self, family_id, at, heading)

## Corner brackets rather than a circle: four short pixel runs stay crisp.
func _selection_bracket(at: Vector2, box: float) -> void:
    var colour: Color = PixelPalette.get_colour("white")
    var arm := 5.0
    for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
        var origin: Vector2 = (at + corner * box).round()
        draw_rect(Rect2(origin - Vector2(arm * maxf(0.0, corner.x), 0.0), Vector2(arm, 1.0)), colour)
        draw_rect(Rect2(origin - Vector2(0.0, arm * maxf(0.0, corner.y)), Vector2(1.0, arm)), colour)
