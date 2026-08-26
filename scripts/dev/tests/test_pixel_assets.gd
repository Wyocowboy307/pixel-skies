extends TestCase
## Verifies the shipped art against docs/PIXEL_STYLE_GUIDE.md.
##
## The style guide is only worth having if it is checked. This walks every PNG
## the game ships and enforces the rules that matter: binary alpha, palette
## conformance, and the exact canvas sizes aircraft sprites must use.

const ART_ROOT := "res://assets/art"
## Sampling keeps the suite fast while still catching a stray colour: a bad
## asset is almost never bad in only a handful of pixels.
const MAX_SAMPLES := 4096

func _palette() -> Dictionary:
    var parsed: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/world/palette.json"))
    var allowed: Dictionary = {}
    if typeof(parsed) != TYPE_DICTIONARY:
        return allowed
    for key: Variant in (parsed as Dictionary).get("palette", {}):
        var colour := Color(String((parsed["palette"] as Dictionary)[key]))
        allowed[colour.to_rgba32()] = String(key)
    return allowed

func _pngs(root: String) -> PackedStringArray:
    var out: PackedStringArray = []
    var dir: DirAccess = DirAccess.open(root)
    if dir == null:
        return out
    for file: String in dir.get_files():
        if file.ends_with(".png"):
            out.append(root.path_join(file))
    for sub: String in dir.get_directories():
        out.append_array(_pngs(root.path_join(sub)))
    return out

func test_assets_use_only_the_locked_palette() -> void:
    var allowed: Dictionary = _palette()
    check(allowed.size() > 20, "palette loaded from data/world/palette.json")
    var offenders: PackedStringArray = []
    var checked := 0
    for path: String in _pngs(ART_ROOT):
        var texture: Texture2D = load(path)
        if texture == null:
            continue
        var image: Image = texture.get_image()
        checked += 1
        var step: int = maxi(1, (image.get_width() * image.get_height()) / MAX_SAMPLES)
        var index := 0
        var bad := ""
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                index += 1
                if index % step != 0:
                    continue
                var pixel: Color = image.get_pixel(x, y)
                if pixel.a == 0.0:
                    continue
                var opaque := Color(pixel.r, pixel.g, pixel.b, 1.0)
                if not allowed.has(opaque.to_rgba32()):
                    bad = "%s @%d,%d %s" % [path.get_file(), x, y, opaque.to_html(false)]
                    break
            if not bad.is_empty():
                break
        if not bad.is_empty():
            offenders.append(bad)
    check(checked > 30, "found the shipped art to check (%d files)" % checked)
    check(offenders.is_empty(), "off-palette pixels: %s" % ", ".join(offenders))

func test_sprites_have_hard_edges() -> void:
    # Alpha must be 0 or 255. A partially transparent edge is an anti-aliased
    # edge, which the style guide rejects outright.
    var offenders: PackedStringArray = []
    for path: String in _pngs(ART_ROOT):
        if path.contains("/world/world_lod"):
            continue    # map tiers are fully opaque by construction
        var texture: Texture2D = load(path)
        if texture == null:
            continue
        var image: Image = texture.get_image()
        var step: int = maxi(1, (image.get_width() * image.get_height()) / MAX_SAMPLES)
        var index := 0
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                index += 1
                if index % step != 0:
                    continue
                var alpha: float = image.get_pixel(x, y).a
                if alpha > 0.02 and alpha < 0.98:
                    offenders.append("%s @%d,%d a=%.2f" % [path.get_file(), x, y, alpha])
                    break
            if offenders.size() > 0 and offenders[offenders.size() - 1].begins_with(path.get_file()):
                break
    check(offenders.is_empty(), "soft edges found: %s" % ", ".join(offenders))

func test_aircraft_sprites_match_their_declared_canvas() -> void:
    # Sizes come from the style guide's canvas ladder, keyed by family.
    var expected: Dictionary = {
        "trailhopper_4": {"top": Vector2i(48, 48), "side": Vector2i(144, 96)},
        "twinwing_8": {"top": Vector2i(64, 64), "side": Vector2i(264, 144)},
        "highline_19": {"top": Vector2i(96, 96), "side": Vector2i(320, 176)},
    }
    for key: String in expected:
        var sizes: Dictionary = expected[key]
        for view: String in ["top", "side"]:
            var path: String = "res://assets/art/aircraft/%s/%s_%s.png" % [key, key, view]
            var texture: Texture2D = load(path)
            check(texture != null, "missing sprite %s" % path)
            if texture != null:
                check_eq(Vector2i(texture.get_size()), sizes[view],
                    "%s %s canvas size" % [key, view])

func test_rotation_strips_are_complete() -> void:
    # Aircraft are never rotated at runtime, so each family needs a full strip
    # of pre-rendered headings.
    for key: String in ["trailhopper_4", "twinwing_8", "highline_19"]:
        var path: String = "res://assets/art/aircraft/%s/%s_top_rot.png" % [key, key]
        var texture: Texture2D = load(path)
        check(texture != null, "missing rotation strip for %s" % key)
        if texture == null:
            continue
        # The strip is N square frames wide; the engine reads N from the strip
        # itself, so the test only requires a whole number of square frames and
        # enough of them to read as rotation rather than snapping.
        var size: Vector2 = texture.get_size()
        var frames: int = int(size.x) / maxi(1, int(size.y))
        check_eq(int(size.x) % maxi(1, int(size.y)), 0, "%s strip is whole frames" % key)
        check(frames >= 16, "%s strip has %d headings, want at least 16" % [key, frames])

func test_surface_tiles_are_sixteen_pixels() -> void:
    for path: String in _pngs("res://assets/art/airports/tiles"):
        var texture: Texture2D = load(path)
        if texture != null:
            check_eq(Vector2i(texture.get_size()), Vector2i(16, 16),
                "%s is a 16px tile" % path.get_file())

func test_starter_kit_is_complete() -> void:
    # The locked starter kit. Anything the UI or airport scene reaches for has
    # to exist, or it silently renders nothing at gameplay size.
    var expected: Dictionary = {
        "res://assets/art/ui/icons/%s.png": [
            "passenger", "cargo", "contract", "money", "clock", "plane", "warning",
            "fuel", "range", "route", "condition", "seat_slot", "cargo_slot",
            "upgrade", "speed", "runway",
        ],
        "res://assets/art/airports/buildings/%s.png": [
            "terminal_1", "terminal_2", "terminal_3", "hangar_small",
            "cargo_shed", "tower", "fuel_depot",
        ],
        "res://assets/art/airports/props/%s.png": [
            "windsock", "apron_light", "runway_sign", "fence",
        ],
        "res://assets/art/airports/vehicles/%s.png": ["tug", "fuel_truck", "baggage_cart"],
        "res://assets/art/cargo/crate_%s.png": ["box", "mail", "medical", "livestock"],
    }
    for pattern: String in expected:
        for name: String in expected[pattern]:
            var path: String = pattern % name
            check(ResourceLoader.exists(path), "missing starter-kit asset %s" % path)

func test_every_aircraft_family_has_a_full_sprite_set() -> void:
    var db := GameDB.new()
    db.load_all()
    for family_id: String in db.aircraft:
        var key: String = family_id.replace("ac_", "")
        for suffix: String in ["top", "side", "top_rot", "map_rot"]:
            var path: String = "res://assets/art/aircraft/%s/%s_%s.png" % [key, key, suffix]
            check(ResourceLoader.exists(path), "missing %s sprite for %s" % [suffix, family_id])
