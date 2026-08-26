class_name WorldProjection
extends RefCounted
## Geographic <-> render-space conversion.
##
## Canonical positions are always latitude/longitude. World space is a fixed
## 4096x2048 equirectangular canvas; every LOD texture is a power-of-two
## fraction of it, so each tier draws at an integer scale.

const EARTH_RADIUS_NM := 3440.065
const WORLD_SIZE := Vector2(4096.0, 2048.0)

static func lat_lon_to_map(lat: float, lon: float, canvas_size: Vector2) -> Vector2:
    var x := ((lon + 180.0) / 360.0) * canvas_size.x
    var y := ((90.0 - lat) / 180.0) * canvas_size.y
    return Vector2(x, y)

static func map_to_lat_lon(pos: Vector2, canvas_size: Vector2) -> Vector2:
    var lon := (pos.x / canvas_size.x) * 360.0 - 180.0
    var lat := 90.0 - (pos.y / canvas_size.y) * 180.0
    return Vector2(lat, lon)

## Project into the canonical world canvas.
static func to_world(lat: float, lon: float) -> Vector2:
    return lat_lon_to_map(lat, lon, WORLD_SIZE)

static func from_world(pos: Vector2) -> Vector2:
    return map_to_lat_lon(pos, WORLD_SIZE)

static func great_circle_nm(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    var phi1 := deg_to_rad(lat1)
    var phi2 := deg_to_rad(lat2)
    var dphi := deg_to_rad(lat2 - lat1)
    var dlambda := deg_to_rad(wrap_lon(lon2 - lon1))
    var a := sin(dphi * 0.5) ** 2 + cos(phi1) * cos(phi2) * sin(dlambda * 0.5) ** 2
    var c := 2.0 * atan2(sqrt(a), sqrt(maxf(0.0, 1.0 - a)))
    return EARTH_RADIUS_NM * c

static func wrap_lon(lon: float) -> float:
    return fposmod(lon + 180.0, 360.0) - 180.0

## Great-circle interpolation. Long routes must not be drawn as straight lines
## in equirectangular space, or they cut through the wrong geography.
static func interpolate_great_circle(lat1: float, lon1: float, lat2: float, lon2: float, t: float) -> Vector2:
    var phi1 := deg_to_rad(lat1)
    var lambda1 := deg_to_rad(lon1)
    var phi2 := deg_to_rad(lat2)
    var lambda2 := deg_to_rad(lon2)
    var d := 2.0 * asin(clampf(sqrt(
        sin((phi1 - phi2) * 0.5) ** 2
        + cos(phi1) * cos(phi2) * sin((lambda1 - lambda2) * 0.5) ** 2), 0.0, 1.0))
    if d < 1e-9:
        return Vector2(lat1, lon1)
    var a := sin((1.0 - t) * d) / sin(d)
    var b := sin(t * d) / sin(d)
    var x := a * cos(phi1) * cos(lambda1) + b * cos(phi2) * cos(lambda2)
    var y := a * cos(phi1) * sin(lambda1) + b * cos(phi2) * sin(lambda2)
    var z := a * sin(phi1) + b * sin(phi2)
    return Vector2(rad_to_deg(atan2(z, sqrt(x * x + y * y))), rad_to_deg(atan2(y, x)))

## Initial compass bearing in degrees, used to orient aircraft sprites.
static func bearing_degrees(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    var phi1 := deg_to_rad(lat1)
    var phi2 := deg_to_rad(lat2)
    var dlambda := deg_to_rad(wrap_lon(lon2 - lon1))
    var y := sin(dlambda) * cos(phi2)
    var x := cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dlambda)
    return fposmod(rad_to_deg(atan2(y, x)), 360.0)
