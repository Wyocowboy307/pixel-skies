class_name LiverySprites
extends RefCounted
## Runtime livery recolouring.
##
## Every aircraft sprite is palette-locked, so a livery is an exact colour-for-
## colour substitution: no blending, no tinting, and the result stays inside the
## locked palette because every target is a palette entry. Works identically on
## pipeline-drawn and PixelLab-approved art, since approval snaps production
## sprites to the same palette.
##
## Tail colour is applied by region (the tail is the rear ~30% of the airframe,
## nose pointing east) because the fin shares the body colours; rotation strips
## skip the tail pass, since the region no longer means anything once the sprite
## has been rotated.

## name -> [light, base, dark] palette keys. "" and "cream" mean the default.
const BODY_SETS := {
    "cream": ["livery_light", "livery", "livery_dark"],
    "sky": ["btn_blue_hi", "btn_blue", "btn_blue_lo"],
    "mint": ["btn_green_hi", "btn_green", "btn_green_lo"],
    "sunset": ["accent_orange_light", "accent_orange", "accent_red"],
    "arctic": ["white", "ice", "tundra"],
    "charcoal": ["metal_light", "metal", "metal_dark"],
}

## name -> [hi, base, dark]. "" and "orange" mean the default.
const ACCENT_SETS := {
    "orange": ["accent_orange_light", "accent_orange", "accent_red"],
    "teal": ["glass_light", "accent_teal", "btn_blue_lo"],
    "yellow": ["card_hi", "accent_yellow", "sand"],
    "red": ["btn_red", "accent_red", "soil"],
    "green": ["btn_green_hi", "btn_green", "btn_green_lo"],
    "navy": ["hud_blue", "btn_blue_lo", "navy"],
}

## Which palette keys count as body/accent in the source art, by shading role.
## Includes both the pipeline keys and the keys PixelLab approvals snap to.
const BODY_SRC := {
    "light": ["livery_light", "panel_light", "map_desert_light", "card"],
    "base": ["livery", "panel_shade", "map_desert"],
    "dark": ["livery_dark", "sand_light", "sand"],
}
const ACCENT_SRC := {
    "light": ["accent_orange_light", "accent_yellow"],
    "base": ["accent_orange", "btn_red"],
    "dark": ["accent_red"],
}

const TAIL_FRACTION := 0.30

static var _cache: Dictionary = {}

static func body_options() -> Array:
    return BODY_SETS.keys()

static func accent_options() -> Array:
    return ACCENT_SETS.keys()

static func is_default(plane: AircraftInstance) -> bool:
    return (plane.livery_body.is_empty() or plane.livery_body == "cream") \
        and (plane.livery_accent.is_empty() or plane.livery_accent == "orange") \
        and plane.livery_tail.is_empty()

# ---------------------------------------------------------------------------
# Texture access
# ---------------------------------------------------------------------------

static func side_texture(plane: AircraftInstance) -> Texture2D:
    var base: Texture2D = AircraftSprites.side_sprite(plane.family_id)
    return _for(plane, base, "side", true)

static func ground_strip(plane: AircraftInstance) -> Texture2D:
    var base: Texture2D = AircraftSprites.ground_strip(plane.family_id)
    return _for(plane, base, "ground", false)

static func map_strip(plane: AircraftInstance, bank: int = 0) -> Texture2D:
    var base: Texture2D = AircraftSprites.map_strip_banked(plane.family_id, bank)
    return _for(plane, base, "map%d" % bank, false)

static func _for(plane: AircraftInstance, base: Texture2D, kind: String,
        tail_pass: bool) -> Texture2D:
    if base == null or plane == null or is_default(plane):
        return base
    var key: String = "%s|%s|%s|%s|%s" % [
        plane.family_id, kind, plane.livery_body, plane.livery_accent, plane.livery_tail]
    if _cache.has(key):
        return _cache[key]
    var recoloured: Texture2D = _recolour(base, plane, tail_pass)
    _cache[key] = recoloured
    return recoloured

## Called when a livery changes, so stale textures are not served.
static func invalidate(plane: AircraftInstance) -> void:
    var prefix: String = plane.family_id + "|"
    for key: Variant in _cache.keys():
        if String(key).begins_with(prefix):
            _cache.erase(key)

# ---------------------------------------------------------------------------
# Recolouring
# ---------------------------------------------------------------------------

static func _mapping(src_roles: Dictionary, target_keys: Array) -> Dictionary:
    var out: Dictionary = {}
    var roles: Array[String] = ["light", "base", "dark"]
    for index in range(roles.size()):
        var target: Color = PixelPalette.get_colour(String(target_keys[mini(index, target_keys.size() - 1)]))
        for src_key: Variant in src_roles.get(roles[index], []):
            out[PixelPalette.get_colour(String(src_key)).to_rgba32()] = target
    return out

static func _recolour(base: Texture2D, plane: AircraftInstance, tail_pass: bool) -> Texture2D:
    var image: Image = base.get_image().duplicate()
    image.convert(Image.FORMAT_RGBA8)

    var body_map: Dictionary = {}
    if not plane.livery_body.is_empty() and plane.livery_body != "cream" \
            and BODY_SETS.has(plane.livery_body):
        body_map = _mapping(BODY_SRC, BODY_SETS[plane.livery_body])
    var accent_map: Dictionary = {}
    if not plane.livery_accent.is_empty() and plane.livery_accent != "orange" \
            and ACCENT_SETS.has(plane.livery_accent):
        accent_map = _mapping(ACCENT_SRC, ACCENT_SETS[plane.livery_accent])
    var tail_map: Dictionary = {}
    var tail_limit := -1
    if tail_pass and not plane.livery_tail.is_empty() and BODY_SETS.has(plane.livery_tail):
        tail_map = _mapping(BODY_SRC, BODY_SETS[plane.livery_tail])
        tail_limit = _tail_limit(image)

    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel: Color = image.get_pixel(x, y)
            if pixel.a < 0.5:
                continue
            var key: int = Color(pixel.r, pixel.g, pixel.b, 1.0).to_rgba32()
            if accent_map.has(key):
                image.set_pixel(x, y, accent_map[key])
            elif tail_limit >= 0 and x <= tail_limit and tail_map.has(key):
                image.set_pixel(x, y, tail_map[key])
            elif body_map.has(key):
                image.set_pixel(x, y, body_map[key])
    return ImageTexture.create_from_image(image)

## Rightmost x that still counts as tail (nose points east in source sprites).
static func _tail_limit(image: Image) -> int:
    var min_x := image.get_width()
    var max_x := 0
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            if image.get_pixel(x, y).a >= 0.5:
                min_x = mini(min_x, x)
                max_x = maxi(max_x, x)
    if max_x <= min_x:
        return -1
    return min_x + int(float(max_x - min_x) * TAIL_FRACTION)
