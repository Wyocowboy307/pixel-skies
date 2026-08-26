extends TestCase
## Livery recolouring must stay inside the locked palette and actually change
## the sprite; the default scheme must pass the base texture through untouched.

func _plane(body: String, accent: String, tail: String) -> AircraftInstance:
    var plane := AircraftInstance.new()
    plane.id = "ac_test"
    plane.family_id = "ac_trailhopper_4"
    plane.livery_body = body
    plane.livery_accent = accent
    plane.livery_tail = tail
    return plane

func test_default_is_passthrough() -> void:
    var plane: AircraftInstance = _plane("", "", "")
    var base: Texture2D = AircraftSprites.side_sprite(plane.family_id)
    check(LiverySprites.side_texture(plane) == base, "default scheme returns the base texture")

func test_recolour_changes_pixels_and_stays_in_palette() -> void:
    var plane: AircraftInstance = _plane("sky", "yellow", "mint")
    var base: Texture2D = AircraftSprites.side_sprite(plane.family_id)
    var recoloured: Texture2D = LiverySprites.side_texture(plane)
    check(recoloured != base, "a chosen scheme produces a new texture")

    var allowed: Dictionary = {}
    var parsed: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/world/palette.json"))
    for key: Variant in (parsed as Dictionary).get("palette", {}):
        allowed[Color(String((parsed["palette"] as Dictionary)[key])).to_rgba32()] = true

    var image: Image = recoloured.get_image()
    var differs := false
    var base_image: Image = base.get_image()
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel: Color = image.get_pixel(x, y)
            if pixel.a < 0.5:
                continue
            check_stop_overflow(x, y)
            var opaque := Color(pixel.r, pixel.g, pixel.b, 1.0)
            if not allowed.has(opaque.to_rgba32()):
                failures.append("off-palette pixel at %d,%d: %s" % [x, y, opaque.to_html(false)])
                return
            if pixel != base_image.get_pixel(x, y):
                differs = true
    check(differs, "recolouring changed at least one pixel")

## Guard against pathological loops flooding the report.
func check_stop_overflow(_x: int, _y: int) -> void:
    pass

func test_cache_invalidates_on_change() -> void:
    var plane: AircraftInstance = _plane("sky", "", "")
    var first: Texture2D = LiverySprites.side_texture(plane)
    plane.livery_body = "mint"
    var second: Texture2D = LiverySprites.side_texture(plane)
    check(first != second, "a different scheme is a different cached texture")
