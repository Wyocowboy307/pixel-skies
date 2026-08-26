class_name WorldMapView
extends Node2D

const GameDB = preload("res://scripts/data/game_db.gd")
const WorldProjection = preload("res://scripts/world/world_projection.gd")

const WORLD_SIZE := Vector2(2048.0, 1024.0)
const OCEAN := Color("#17364a")
const LAND_PLACEHOLDER := Color("#536c54")
const ROUTE := Color("#8bc6d9")
const AIRPORT := Color("#f4e2a1")
const AIRPORT_MAJOR := Color("#f3ad63")

var db := GameDB.new()

func _ready() -> void:
    db.load_all()
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), OCEAN)

    # Deliberately crude foundation silhouette. Claude should replace this with
    # preprocessed Natural Earth LOD geometry, not hand-maintain this polygon.
    var north_america := PackedVector2Array([
        Vector2(260, 170), Vector2(410, 130), Vector2(560, 170), Vector2(650, 255),
        Vector2(610, 330), Vector2(540, 390), Vector2(500, 470), Vector2(430, 505),
        Vector2(360, 450), Vector2(310, 350), Vector2(245, 300)
    ])
    draw_colored_polygon(north_america, LAND_PLACEHOLDER)

    _draw_route("apt_bzn", "apt_bil")
    _draw_route("apt_bzn", "apt_den")
    _draw_route("apt_bil", "apt_den")

    for airport in db.airports.values():
        var pos := WorldProjection.lat_lon_to_map(float(airport["lat"]), float(airport["lon"]), WORLD_SIZE)
        var radius := 8.0 if String(airport["tier"]) == "major" else 6.0
        var color := AIRPORT_MAJOR if String(airport["tier"]) == "major" else AIRPORT
        draw_circle(pos, radius, color)
        draw_circle(pos, radius + 3.0, Color(color, 0.2), false, 2.0)
        draw_string(ThemeDB.fallback_font, pos + Vector2(10, 5), String(airport["code"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_route(a_id: String, b_id: String) -> void:
    var a: Dictionary = db.airports[a_id]
    var b: Dictionary = db.airports[b_id]
    var pa := WorldProjection.lat_lon_to_map(float(a["lat"]), float(a["lon"]), WORLD_SIZE)
    var pb := WorldProjection.lat_lon_to_map(float(b["lat"]), float(b["lon"]), WORLD_SIZE)
    draw_dashed_line(pa, pb, ROUTE, 2.0, 8.0, true)
