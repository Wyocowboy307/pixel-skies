class_name WorldProjection
extends RefCounted

const EARTH_RADIUS_NM := 3440.065

static func lat_lon_to_map(lat: float, lon: float, canvas_size: Vector2) -> Vector2:
    var x := ((lon + 180.0) / 360.0) * canvas_size.x
    var y := ((90.0 - lat) / 180.0) * canvas_size.y
    return Vector2(x, y)

static func map_to_lat_lon(pos: Vector2, canvas_size: Vector2) -> Vector2:
    var lon := (pos.x / canvas_size.x) * 360.0 - 180.0
    var lat := 90.0 - (pos.y / canvas_size.y) * 180.0
    return Vector2(lat, lon)

static func great_circle_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    var phi1 := deg_to_rad(lat1)
    var phi2 := deg_to_rad(lat2)
    var dphi := deg_to_rad(lat2 - lat1)
    var dlambda := deg_to_rad(lon2 - lon1)
    var a := sin(dphi * 0.5) ** 2 + cos(phi1) * cos(phi2) * sin(dlambda * 0.5) ** 2
    var c := 2.0 * atan2(sqrt(a), sqrt(maxf(0.0, 1.0 - a)))
    return EARTH_RADIUS_NM * c

static func wrap_lon(lon: float) -> float:
    return fposmod(lon + 180.0, 360.0) - 180.0
