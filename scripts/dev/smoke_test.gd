extends SceneTree

const GameDB = preload("res://scripts/data/game_db.gd")
const WorldProjection = preload("res://scripts/world/world_projection.gd")

func _init() -> void:
    var db := GameDB.new()
    db.load_all()
    assert(db.airports.size() == 3)
    assert(db.aircraft.size() == 3)

    var bzn: Dictionary = db.airports["apt_bzn"]
    var bil: Dictionary = db.airports["apt_bil"]
    var distance := WorldProjection.great_circle_nm(
        float(bzn["lat"]), float(bzn["lon"]),
        float(bil["lat"]), float(bil["lon"])
    )
    assert(distance > 100.0 and distance < 150.0)

    var canvas := Vector2(2048, 1024)
    var p := WorldProjection.lat_lon_to_map(float(bzn["lat"]), float(bzn["lon"]), canvas)
    var ll := WorldProjection.map_to_lat_lon(p, canvas)
    assert(abs(ll.x - float(bzn["lat"])) < 0.001)
    assert(abs(ll.y - float(bzn["lon"])) < 0.001)

    print("Pixel Skies smoke checks passed.")
    quit(0)
