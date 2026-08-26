class_name AircraftSprites
extends RefCounted
## Loads and draws the pre-rendered aircraft sprites.
##
## Aircraft are never rotated at runtime. An arbitrary rotation resamples the
## sprite and destroys the hard edges the whole style depends on, so each family
## ships a strip of headings drawn at build time and the engine picks the
## nearest (docs/PIXEL_STYLE_GUIDE.md).

const FRAMES := 16
const GROUND_STRIP := "res://assets/art/aircraft/%s/%s_top_rot.png"
const MAP_STRIP := "res://assets/art/aircraft/%s/%s_map_rot.png"
const SIDE_SPRITE := "res://assets/art/aircraft/%s/%s_side.png"

static var _cache: Dictionary = {}

static func _load(path: String) -> Texture2D:
    if not _cache.has(path):
        _cache[path] = load(path) if ResourceLoader.exists(path) else null
    return _cache[path]

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
static func frame_for(heading_radians: float) -> int:
    var frame: int = int(roundf(heading_radians / TAU * float(FRAMES)))
    return ((frame % FRAMES) + FRAMES) % FRAMES

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
    var frame: int = frame_for(heading_radians)
    var region := Rect2(Vector2(float(frame) * frame_size, 0.0), Vector2(frame_size, frame_size))
    var drawn: Vector2 = region.size * float(maxi(1, scale))
    canvas.draw_texture_rect_region(strip, Rect2((at - drawn * 0.5).round(), drawn), region)

static func draw_ground(canvas: CanvasItem, family_id: String, at: Vector2,
        heading_radians: float, scale: int = 1) -> void:
    draw_frame(canvas, ground_strip(family_id), at, heading_radians, scale)

static func draw_map(canvas: CanvasItem, family_id: String, at: Vector2,
        heading_radians: float, scale: int = 1) -> void:
    draw_frame(canvas, map_strip(family_id), at, heading_radians, scale)
