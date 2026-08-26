extends TestCase
## Geographic projection and distance maths.

const CANVAS := Vector2(2048.0, 1024.0)

func test_projection_round_trip() -> void:
    var samples: Array[Vector2] = [
        Vector2(45.7775, -111.1520), Vector2(0.0, 0.0), Vector2(-33.9, 151.2),
        Vector2(64.1, -21.9), Vector2(-54.8, -68.3),
    ]
    for sample: Vector2 in samples:
        var projected: Vector2 = WorldProjection.lat_lon_to_map(sample.x, sample.y, CANVAS)
        var back: Vector2 = WorldProjection.map_to_lat_lon(projected, CANVAS)
        check_near(back.x, sample.x, 0.001, "latitude round trip")
        check_near(back.y, sample.y, 0.001, "longitude round trip")

func test_known_distances() -> void:
    # BZN -> BIL is a real ~109 nm leg; a projection or radius mistake moves this a lot.
    check_between(WorldProjection.great_circle_nm(45.7775, -111.1520, 45.8077, -108.5429),
        100.0, 120.0, "BZN->BIL distance")
    # BZN -> DEN, the slice's aspirational leg.
    check_between(WorldProjection.great_circle_nm(45.7775, -111.1520, 39.8561, -104.6737),
        450.0, 520.0, "BZN->DEN distance")

func test_zero_distance() -> void:
    check_near(WorldProjection.great_circle_nm(45.0, -111.0, 45.0, -111.0), 0.0, 0.0001,
        "identical points are zero apart")

func test_longitude_wrapping() -> void:
    check_near(WorldProjection.wrap_lon(190.0), -170.0, 0.0001, "wrap 190")
    check_near(WorldProjection.wrap_lon(-190.0), 170.0, 0.0001, "wrap -190")
    check_near(WorldProjection.wrap_lon(45.0), 45.0, 0.0001, "wrap in-range value")
    # A date-line crossing must take the short way round, not 350 degrees the wrong way.
    check_between(WorldProjection.great_circle_nm(0.0, 179.0, 0.0, -179.0), 100.0, 130.0,
        "date line crossing takes the short path")
