extends Node2D

const WorldProjection = preload("res://scripts/world/world_projection.gd")

func _ready() -> void:
    var bzn := Vector2(45.7775, -111.1520)
    var p := WorldProjection.lat_lon_to_map(bzn.x, bzn.y, Vector2(2048.0, 1024.0))
    print("Pixel Skies boot OK. BZN projected at ", p)
