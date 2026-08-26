class_name ViewTransition
extends CanvasLayer
## Short fade used to carry the camera from the world map into an airport scene.
##
## The world camera keeps zooming underneath the fade, so the player reads the
## change as a continuous dive rather than a cut (docs/WORLD_MAP_AND_ZOOM.md).

const FADE_COLOR := Color("#050c12")

var _rect: ColorRect

func _ready() -> void:
    layer = 100
    _rect = ColorRect.new()
    _rect.color = FADE_COLOR
    _rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rect.modulate.a = 0.0
    _rect.visible = false
    add_child(_rect)

func cover(duration: float = 0.28) -> void:
    _rect.visible = true
    var tween: Tween = create_tween()
    tween.tween_property(_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
    await tween.finished

func uncover(duration: float = 0.32) -> void:
    var tween: Tween = create_tween()
    tween.tween_property(_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
    await tween.finished
    _rect.visible = false

func is_covering() -> bool:
    return _rect.visible and _rect.modulate.a > 0.99
