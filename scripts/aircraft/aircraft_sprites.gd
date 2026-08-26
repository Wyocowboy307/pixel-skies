class_name AircraftSprites
extends RefCounted
## Loads and draws the pre-rendered aircraft sprites.
##
## Aircraft are never rotated at runtime. An arbitrary rotation resamples the
## sprite and destroys the hard edges the whole style depends on, so each family
## ships a strip of headings drawn at build time and the engine picks the
## nearest (docs/PIXEL_STYLE_GUIDE.md).

## Baked heading count is read from the strip, not hardcoded: the strip is
## always N square frames wide, so re-baking at a different count needs no code
## change.
const DEFAULT_FRAMES := 32
const GROUND_STRIP := "aircraft/%s/%s_top_rot.png"
const MAP_STRIP := "aircraft/%s/%s_map_rot.png"
const SIDE_SPRITE := "aircraft/%s/%s_side.png"

static var _cache: Dictionary = {}

static func _load(logical: String) -> Texture2D:
    if not _cache.has(logical):
        _cache[logical] = AssetPaths.load_texture(logical)
    return _cache[logical]

static func _key(family_id: String) -> String:
    return family_id.replace("ac_", "")

static func ground_strip(family_id: String) -> Texture2D:
    var key: String = _key(family_id)
    return _load(GROUND_STRIP % [key, key])

static func map_strip(family_id: String) -> Texture2D:
    var key: String = _key(family_id)
    return _load(MAP_STRIP % [key, key])

static func side_sprite(family_id: String) -> Texture2D:
    var key: String = _key(family_id)
    return _load(SIDE_SPRITE % [key, key])

## Nearest baked heading. Frame 0 points east (+x) and frames advance clockwise,
## matching screen space where +y is south.
static func frames_in(strip: Texture2D) -> int:
    if strip == null or strip.get_size().y <= 0.0:
        return DEFAULT_FRAMES
    return maxi(1, int(roundf(strip.get_size().x / strip.get_size().y)))

static func frame_for(heading_radians: float, frames: int = DEFAULT_FRAMES) -> int:
    var count: int = maxi(1, frames)
    var frame: int = int(roundf(heading_radians / TAU * float(count)))
    return ((frame % count) + count) % count

## Compass bearing (0 = north, 90 = east) to a screen-space angle.
static func bearing_to_screen(bearing_degrees: float) -> float:
    return deg_to_rad(bearing_degrees - 90.0)

## Draws one heading from a strip, centred on `at` and snapped to whole pixels.
## `scale` must be a whole number: a fractional scale resamples the sprite.
static func draw_frame(canvas: CanvasItem, strip: Texture2D, at: Vector2,
        heading_radians: float, scale: int = 1) -> void:
    if strip == null:
        return
    var frame_size: float = strip.get_size().y
    var frame: int = frame_for(heading_radians, frames_in(strip))
    var region := Rect2(Vector2(float(frame) * frame_size, 0.0), Vector2(frame_size, frame_size))
    var drawn: Vector2 = region.size * float(maxi(1, scale))
    canvas.draw_texture_rect_region(strip, Rect2((at - drawn * 0.5).round(), drawn), region)

static func draw_ground(canvas: CanvasItem, family_id: String, at: Vector2,
        heading_radians: float, scale: int = 1) -> void:
    draw_frame(canvas, ground_strip(family_id), at, heading_radians, scale)

static func draw_map(canvas: CanvasItem, family_id: String, at: Vector2,
        heading_radians: float, scale: int = 1) -> void:
    draw_frame(canvas, map_strip(family_id), at, heading_radians, scale)
