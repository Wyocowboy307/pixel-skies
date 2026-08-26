class_name AirportView
extends Node2D
## Top-down airport ground scene, built from a data-defined AirportLayout.
##
## Local coordinates are centred on (0,0); the world map's geographic space
## never reaches here (docs/TECH_ARCHITECTURE.md, "Airport movement").
## Milestone 4 adds moving aircraft and the ground-service loop on top of this
## same layout data.

const GROUND_PATCHES := 220
const RUNWAY_DASH := 34.0
const RUNWAY_GAP := 26.0

var airport_id := ""
var layout: Dictionary = {}
var airport: Dictionary = {}

var _biome: Dictionary = {}
var _patches: Array[Dictionary] = []

func setup(airport_data: Dictionary, layout_data: Dictionary) -> void:
    airport = airport_data
    layout = layout_data
    airport_id = String(airport_data.get("id", ""))
    _biome = AirportPalette.biome(String(layout.get("biome", "plains")))
    _build_ground_texture()
    queue_redraw()

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Scatter is generated once from a fixed seed so the ground never shimmers
## between frames and looks identical every time this airport is opened.
func _build_ground_texture() -> void:
    _patches.clear()
    var extent: Vector2 = _extent()
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(airport_id)
    for i in range(GROUND_PATCHES):
        _patches.append({
            "position": Vector2(
                rng.randf_range(-extent.x, extent.x),
                rng.randf_range(-extent.y, extent.y)),
            "size": Vector2(rng.randf_range(14.0, 46.0), rng.randf_range(8.0, 22.0)),
        })

func _extent() -> Vector2:
    var raw: Array = layout.get("ground_extent", [1500, 900])
    return Vector2(float(raw[0]), float(raw[1])) * 0.5

func bounds() -> Rect2:
    var extent: Vector2 = _extent()
    return Rect2(-extent, extent * 2.0)

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

func _all_runways() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var primary: Dictionary = layout.get("runway", {})
    if not primary.is_empty():
        out.append(primary)
    for extra: Variant in layout.get("secondary_runways", []):
        out.append(extra as Dictionary)
    return out

func _draw_ground() -> void:
    var extent: Vector2 = _extent()
    # Oversized so panning at the edge of the scene never shows through.
    draw_rect(Rect2(-extent * 1.6, extent * 3.2), _biome["ground"])
    for patch: Dictionary in _patches:
        draw_rect(Rect2(patch["position"], patch["size"]), _biome["ground_alt"])

## Regional flavour comes from modular decoration rather than a bespoke tileset
## per airport (docs/ART_BIBLE.md, "Biomes"). Everything is seeded from the
## airport id, so a field looks the same every time it is opened.
func _draw_decor() -> void:
    var index := 0
    for item: Variant in layout.get("decor", []):
        var decor: Dictionary = item
        var position: Vector2 = _vec(decor.get("position", [0, 0]))
        var size: Vector2 = _vec(decor.get("size", [100, 60]))
        var kind: String = String(decor.get("type", "trees"))
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("%s_decor_%d" % [airport_id, index])
        index += 1
        match kind:
            "ridge": _draw_ridge(position, size, rng)
            "trees": _draw_trees(position, size, rng)
            "fields": _draw_fields(position, size, rng)
            _: _draw_scrub(position, size, rng)

## Ridges read as forested foothills seen from above: overlapping canopy masses
## with occasional rock breaking through. Flat-lay perspective is preserved
## (docs/ART_BIBLE.md) without pretending flat polygons are a mountain — the
## real mountain tiles come from the art pipeline in Phase B.
func _draw_ridge(centre: Vector2, size: Vector2, rng: RandomNumberGenerator) -> void:
    var canopy: Color = _biome["decor"].darkened(0.22)
    var rock: Color = _biome["ridge"]
    var clumps: int = maxi(10, int(size.x * size.y / 2600.0))
    for _i in range(clumps):
        var at := centre + Vector2(
            rng.randf_range(-size.x, size.x) * 0.5,
            rng.randf_range(-size.y, size.y) * 0.5)
        var radius: float = rng.randf_range(18.0, 40.0)
        draw_circle(at + Vector2(4.0, 5.0), radius, AirportPalette.SHADOW)
        draw_circle(at, radius, canopy)
        # Upper-left light catches the north-west shoulder of each mass.
        draw_circle(at - Vector2(radius * 0.34, radius * 0.34), radius * 0.4,
            Color(AirportPalette.MARK_WHITE, 0.07))
    # A few exposed crests so a mountain field still reads as high country.
    var crests: int = maxi(2, clumps / 6)
    for _i in range(crests):
        var at := centre + Vector2(
            rng.randf_range(-size.x, size.x) * 0.42,
            rng.randf_range(-size.y, size.y) * 0.36)
        var radius: float = rng.randf_range(11.0, 20.0)
        draw_circle(at, radius, rock)
        draw_circle(at - Vector2(radius * 0.3, radius * 0.3), radius * 0.45,
            Color(AirportPalette.MARK_WHITE, 0.16))

func _draw_trees(centre: Vector2, size: Vector2, rng: RandomNumberGenerator) -> void:
    var count: int = int(size.x * size.y / 900.0)
    for _i in range(count):
        var at := centre + Vector2(
            rng.randf_range(-size.x, size.x) * 0.5,
            rng.randf_range(-size.y, size.y) * 0.5)
        var radius: float = rng.randf_range(6.0, 13.0)
        draw_circle(at + Vector2(2.0, 3.0), radius, AirportPalette.SHADOW)
        draw_circle(at, radius, _biome["decor"])
        draw_circle(at - Vector2(radius * 0.3, radius * 0.3), radius * 0.42,
            Color(AirportPalette.MARK_WHITE, 0.08))

## Crop rows: the plains read as farmed rather than as a green rectangle.
func _draw_fields(centre: Vector2, size: Vector2, rng: RandomNumberGenerator) -> void:
    var rect := Rect2(centre - size * 0.5, size)
    draw_rect(rect, _biome["decor"])
    var rows: int = maxi(3, int(size.y / 18.0))
    for i in range(rows):
        var y: float = rect.position.y + (float(i) + 0.5) * size.y / float(rows)
        var inset: float = rng.randf_range(0.0, size.x * 0.06)
        draw_line(Vector2(rect.position.x + inset, y),
            Vector2(rect.position.x + size.x - inset, y),
            Color(_biome["ground_alt"], 0.55), 2.0)
    draw_rect(rect, Color(AirportPalette.OUTLINE, 0.18), false, 1.0)

func _draw_scrub(centre: Vector2, size: Vector2, rng: RandomNumberGenerator) -> void:
    var count: int = int(size.x * size.y / 700.0)
    for _i in range(count):
        var at := centre + Vector2(
            rng.randf_range(-size.x, size.x) * 0.5,
            rng.randf_range(-size.y, size.y) * 0.5)
        draw_rect(Rect2(at, Vector2(rng.randf_range(5.0, 11.0), rng.randf_range(3.0, 6.0))),
            _biome["decor"])

func _draw_runway(runway: Dictionary) -> void:
    var start: Vector2 = _vec(runway.get("start", [0, 0]))
    var end: Vector2 = _vec(runway.get("end", [0, 0]))
    var width: float = float(runway.get("width", 44.0))
    var axis: Vector2 = (end - start).normalized()
    var normal := Vector2(-axis.y, axis.x)
    var half: Vector2 = normal * width * 0.5

    # Surface, with a shoulder so the runway reads as raised off the grass.
    var shoulder: Vector2 = normal * (width * 0.5 + 7.0)
    draw_colored_polygon(PackedVector2Array([
        start + shoulder, end + shoulder, end - shoulder, start - shoulder]),
        AirportPalette.ASPHALT_EDGE)
    draw_colored_polygon(PackedVector2Array([
        start + half, end + half, end - half, start - half]), AirportPalette.ASPHALT)

    # Edge lines make the runway instantly distinct from taxiway and apron.
    draw_line(start + half, end + half, AirportPalette.MARK_WHITE, 2.0)
    draw_line(start - half, end - half, AirportPalette.MARK_WHITE, 2.0)

    _draw_centreline(start, end, axis)
    _draw_threshold(start, axis, normal, width)
    _draw_threshold(end, -axis, normal, width)
    _draw_designations(runway, start, end, axis, normal, width)

func _draw_centreline(start: Vector2, end: Vector2, axis: Vector2) -> void:
    var length: float = start.distance_to(end)
    var travelled: float = 90.0
    while travelled < length - 90.0:
        var a: Vector2 = start + axis * travelled
        var b: Vector2 = start + axis * minf(travelled + RUNWAY_DASH, length - 90.0)
        draw_line(a, b, AirportPalette.MARK_WHITE, 2.0)
        travelled += RUNWAY_DASH + RUNWAY_GAP

## Piano-key threshold bars: the clearest possible "this end is a runway" cue.
func _draw_threshold(at: Vector2, inward: Vector2, normal: Vector2, width: float) -> void:
    var bars := 6
    var bar_width: float = width / float(bars * 2 - 1)
    var base: Vector2 = at + inward * 18.0
    for i in range(bars):
        var offset: float = (float(i) - float(bars - 1) * 0.5) * bar_width * 2.0
        var centre: Vector2 = base + normal * offset
        var a: Vector2 = centre - normal * bar_width * 0.5
        var b: Vector2 = centre + normal * bar_width * 0.5
        draw_colored_polygon(PackedVector2Array([
            a, b, b + inward * 34.0, a + inward * 34.0]), AirportPalette.MARK_WHITE)

func _draw_designations(runway: Dictionary, start: Vector2, end: Vector2,
        axis: Vector2, normal: Vector2, _width: float) -> void:
    var designations: Array = runway.get("designations", [])
    if designations.size() < 2:
        return
    var font: Font = ThemeDB.fallback_font
    _draw_rotated_text(String(designations[0]), start + axis * 74.0, axis, normal, font)
    _draw_rotated_text(String(designations[1]), end - axis * 74.0, -axis, normal, font)

## Runway numbers are painted on the surface, so they read along the direction
## of travel rather than along the screen.
func _draw_rotated_text(text: String, at: Vector2, axis: Vector2, _normal: Vector2, font: Font) -> void:
    var font_size := 26
    var extents: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_set_transform(at, axis.angle() - PI * 0.5, Vector2.ONE)
    draw_string(font, Vector2(-extents.x * 0.5, extents.y * 0.32), text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(AirportPalette.MARK_WHITE, 0.9))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_taxiways() -> void:
    for item: Variant in layout.get("taxiways", []):
        var taxiway: Dictionary = item
        var points: PackedVector2Array = _points(taxiway.get("points", []))
        if points.size() < 2:
            continue
        # A tone shift plus a yellow centreline is what separates taxiway from
        # runway at a glance (docs/ART_BIBLE.md, "Airport readability").
        draw_polyline(points, AirportPalette.TAXIWAY_EDGE, 34.0)
        draw_polyline(points, AirportPalette.TAXIWAY, 28.0)
        draw_polyline(points, AirportPalette.MARK_YELLOW, 2.0)

func _draw_apron() -> void:
    var apron: Dictionary = layout.get("apron", {})
    if apron.is_empty():
        return
    var centre: Vector2 = _vec(apron.get("centre", [0, 0]))
    var size: Vector2 = _vec(apron.get("size", [300, 120]))
    var rect := Rect2(centre - size * 0.5, size)
    draw_rect(rect.grow(3.0), AirportPalette.CONCRETE_EDGE)
    draw_rect(rect, AirportPalette.CONCRETE)

func _draw_stands() -> void:
    var font: Font = ThemeDB.fallback_font
    for item: Variant in layout.get("stands", []):
        var stand: Dictionary = item
        var position: Vector2 = _vec(stand.get("position", [0, 0]))
        var heading: float = deg_to_rad(float(stand.get("heading", 90.0)))
        var facing := Vector2(cos(heading), sin(heading))
        var across := Vector2(-facing.y, facing.x)
        var span: float = _stand_span(String(stand.get("size", "small")))

        # Lead-in line and a stop bar: the visual language of a parking stand.
        draw_line(position - facing * span * 1.4, position, AirportPalette.MARK_YELLOW, 2.0)
        draw_line(position - across * span * 0.5, position + across * span * 0.5,
            AirportPalette.MARK_YELLOW, 3.0)
        draw_arc(position, span * 0.62, 0.0, TAU, 24, Color(AirportPalette.MARK_YELLOW, 0.4), 1.0)
        draw_string(font, position + across * span * 0.5 + Vector2(6.0, -6.0),
            String(stand.get("id", "")).replace("stand_", "S"),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(AirportPalette.MARK_YELLOW, 0.85))

func _stand_span(size_name: String) -> float:
    match size_name:
        "large": return 92.0
        "medium": return 68.0
        _: return 48.0

## Buildings get a roof plus a short south face, the "tiny amount of readable
## side information" the art bible allows in an otherwise flat-lay view.
func _draw_buildings() -> void:
    var font: Font = ThemeDB.fallback_font
    for item: Variant in layout.get("buildings", []):
        var building: Dictionary = item
        var position: Vector2 = _vec(building.get("position", [0, 0]))
        var size: Vector2 = _vec(building.get("size", [120, 60]))
        var kind: String = String(building.get("type", "cargo"))
        var rect := Rect2(position - size * 0.5, size)
        var roof: Color = AirportPalette.building_roof(kind)

        draw_rect(Rect2(rect.position + Vector2(5.0, 7.0), rect.size), AirportPalette.SHADOW)
        draw_rect(rect, roof)
        draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y), Vector2(rect.size.x, 10.0)),
            AirportPalette.TERMINAL_FACE)
        draw_rect(rect, AirportPalette.OUTLINE, false, 1.0)
        # Upper-left light: a thin highlight along the north edge.
        draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0),
            Color(AirportPalette.MARK_WHITE, 0.18), 1.0)

        if kind == "terminal":
            var code: String = String(airport.get("code", ""))
            var extents: Vector2 = font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
            draw_string(font, position - Vector2(extents.x * 0.5, -6.0), code,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(AirportPalette.MARK_WHITE, 0.75))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _vec(raw: Variant) -> Vector2:
    var array: Array = raw
    if array.size() < 2:
        return Vector2.ZERO
    return Vector2(float(array[0]), float(array[1]))

func _points(raw: Variant) -> PackedVector2Array:
    var out: PackedVector2Array = []
    for entry: Variant in (raw as Array):
        out.append(_vec(entry))
    return out
