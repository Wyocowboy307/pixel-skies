extends TestCase
## Camera framing maths — the "seamless zoom" promise in docs/WORLD_MAP_AND_ZOOM.md.

const VIEWPORT := Vector2(1280.0, 720.0)

func test_project_round_trip() -> void:
    var camera_pos := Vector2(1500.0, 700.0)
    for zoom: float in [0.25, 0.5, 1.0, 2.0, 8.0]:
        var world := Vector2(1712.0, 640.0)
        var screen: Vector2 = WorldCamera.project(camera_pos, zoom, VIEWPORT, world)
        var back: Vector2 = WorldCamera.unproject(camera_pos, zoom, VIEWPORT, screen)
        check_near(back.x, world.x, 0.001, "x round trip at zoom %f" % zoom)
        check_near(back.y, world.y, 0.001, "y round trip at zoom %f" % zoom)

func test_zoom_keeps_anchor_point_fixed() -> void:
    # Zooming must grow the map around the cursor: the world point under the
    # anchor before the zoom must still be under it afterwards.
    var camera_pos := Vector2(1500.0, 700.0)
    var anchor := Vector2(980.0, 240.0)
    var before: Vector2 = WorldCamera.unproject(camera_pos, 1.0, VIEWPORT, anchor)
    for zoom: float in [0.25, 0.5, 2.0, 4.0, 8.0]:
        var moved: Vector2 = WorldCamera.anchored_position(before, zoom, VIEWPORT, anchor)
        var after: Vector2 = WorldCamera.unproject(moved, zoom, VIEWPORT, anchor)
        check_near(after.x, before.x, 0.01, "anchor x holds at zoom %f" % zoom)
        check_near(after.y, before.y, 0.01, "anchor y holds at zoom %f" % zoom)

func test_focus_centres_when_no_anchor_given() -> void:
    var target := Vector2(1712.0, 640.0)
    var centre: Vector2 = VIEWPORT * 0.5
    var camera_pos: Vector2 = WorldCamera.anchored_position(target, 2.0, VIEWPORT, centre)
    check_near(camera_pos.x, target.x, 0.001, "centred focus x")
    check_near(camera_pos.y, target.y, 0.001, "centred focus y")

func test_zoom_stops_are_pixel_friendly() -> void:
    # Every stop must pick a LOD that renders at a whole number of screen pixels
    # per texel, otherwise the map shimmers as it scales.
    for zoom: float in WorldCamera.ZOOM_STOPS:
        var tier: int = WorldLod.tier_for_zoom(zoom)
        var pixels_per_texel: float = WorldLod.world_scale(tier) * zoom
        check(pixels_per_texel >= 1.0, "zoom %f downsamples the map (%f px/texel)" % [zoom, pixels_per_texel])
        check_near(pixels_per_texel, roundf(pixels_per_texel), 0.0001,
            "zoom %f is not an integer texel scale" % zoom)
