extends TestCase
## Taxi path sampling. Aircraft must move along the authored route at a steady
## pace rather than jumping between waypoints.

func _l_shape() -> PackedVector2Array:
    # 100 across, then 100 down: total length 200.
    return PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])

func test_length() -> void:
    check_near(GroundPath.length_of(_l_shape()), 200.0, 0.001, "polyline length")

func test_endpoints() -> void:
    var path := _l_shape()
    check(GroundPath.sample(path, 0.0).is_equal_approx(Vector2(0, 0)), "starts at the first point")
    check(GroundPath.sample(path, 1.0).is_equal_approx(Vector2(100, 100)), "ends at the last point")

func test_midpoint_is_measured_by_distance_not_by_waypoint() -> void:
    # Half the *length* is the corner, not the middle waypoint index.
    var at: Vector2 = GroundPath.sample(_l_shape(), 0.5)
    check_near(at.x, 100.0, 0.001, "halfway is the corner x")
    check_near(at.y, 0.0, 0.001, "halfway is the corner y")

func test_constant_speed() -> void:
    # Equal steps in t must cover equal distance, or the aircraft visibly
    # speeds up and slows down at every waypoint.
    var path := _l_shape()
    var previous: Vector2 = GroundPath.sample(path, 0.0)
    var first_step := 0.0
    for i in range(1, 11):
        var at: Vector2 = GroundPath.sample(path, float(i) / 10.0)
        var step: float = previous.distance_to(at)
        if i == 1:
            first_step = step
        else:
            check_near(step, first_step, 0.001, "step %d matches the first" % i)
        previous = at

func test_heading_follows_the_route() -> void:
    var path := _l_shape()
    check_near(GroundPath.heading_at(path, 0.1), 0.0, 0.05, "heads east along the first leg")
    check_near(GroundPath.heading_at(path, 0.9), PI * 0.5, 0.05, "heads south along the second")

func test_degenerate_paths_do_not_crash() -> void:
    check(GroundPath.sample(PackedVector2Array(), 0.5) == Vector2.ZERO, "empty path is safe")
    var single := PackedVector2Array([Vector2(5, 5)])
    check(GroundPath.sample(single, 0.7).is_equal_approx(Vector2(5, 5)), "single point is safe")
    check_near(GroundPath.heading_at(single, 0.5), 0.0, 0.001, "single point heading is safe")
