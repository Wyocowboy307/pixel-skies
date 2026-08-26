class_name PixelPalette
extends RefCounted
## The locked palette, read from the same file the art was generated from.
##
## UI colours therefore cannot drift away from the sprites: both come from
## tools/pixelart/palette.py via data/world/palette.json.

const PATH := "res://data/world/palette.json"

static var _colours: Dictionary = {}

static func _load() -> void:
    if not _colours.is_empty():
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Missing palette at %s — run tools/build_pixel_assets.py" % PATH)
        return
    for key: Variant in (parsed as Dictionary).get("palette", {}):
        _colours[String(key)] = Color(String((parsed["palette"] as Dictionary)[key]))

static func get_colour(key: String) -> Color:
    _load()
    if not _colours.has(key):
        push_error("Colour '%s' is not in the locked palette" % key)
        return Color.MAGENTA
    return _colours[key]

static func has(key: String) -> bool:
    _load()
    return _colours.has(key)
