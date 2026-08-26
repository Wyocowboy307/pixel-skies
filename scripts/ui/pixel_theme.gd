class_name PixelTheme
extends RefCounted
## Builds the game's Theme from the generated pixel frames.
##
## Every panel, button and row is a 9-slice of a hand-generated sprite, so the
## management UI belongs to the same world as the airfield beneath it. Nothing
## here uses a rounded rect, a gradient or a system font.

const FONT := "res://assets/art/ui/font5x7.fnt"
const FRAME_DIR := "res://assets/art/ui/%s.png"
const FONT_SIZE := 7

static func build() -> Theme:
    var theme := Theme.new()
    var font: Font = load(FONT)
    theme.default_font = font
    theme.default_font_size = FONT_SIZE

    # Warm card panels rather than dark instrument bezels.
    theme.set_stylebox("panel", "PanelContainer", _frame("warm_panel", 4, 3))
    theme.set_stylebox("panel", "Panel", _frame("warm_panel", 4, 3))

    for state: String in ["normal", "hover", "pressed", "disabled"]:
        theme.set_stylebox(state, "Button", _frame("warm_button_%s" % state, 3, 2))
    theme.set_stylebox("focus", "Button", _frame("warm_button_hover", 3, 2))
    theme.set_font("font", "Button", font)
    theme.set_font_size("font_size", "Button", FONT_SIZE)
    theme.set_color("font_color", "Button", PixelPalette.get_colour("ink"))
    theme.set_color("font_hover_color", "Button", PixelPalette.get_colour("panel_deep"))
    theme.set_color("font_pressed_color", "Button", PixelPalette.get_colour("panel_deep"))
    theme.set_color("font_disabled_color", "Button", PixelPalette.get_colour("ink_soft"))
    theme.set_constant("h_separation", "Button", 2)

    # Big obvious action buttons — Load, Route, Fly — as a type variation.
    for state: String in ["normal", "hover", "pressed", "disabled"]:
        theme.set_stylebox(state, "ActionButton", _frame("action_%s" % state, 4, 4))
    theme.set_type_variation("ActionButton", "Button")
    theme.set_font("font", "ActionButton", font)
    theme.set_font_size("font_size", "ActionButton", FONT_SIZE)
    theme.set_color("font_color", "ActionButton", PixelPalette.get_colour("panel_deep"))
    theme.set_color("font_hover_color", "ActionButton", PixelPalette.get_colour("panel_deep"))
    theme.set_color("font_pressed_color", "ActionButton", PixelPalette.get_colour("white"))
    theme.set_color("font_disabled_color", "ActionButton", PixelPalette.get_colour("ink_soft"))

    theme.set_font("font", "Label", font)
    theme.set_font_size("font_size", "Label", FONT_SIZE)
    theme.set_color("font_color", "Label", PixelPalette.get_colour("ink"))

    # Scrollbars: thin solid bars, no rounded grabbers.
    for axis: String in ["VScrollBar", "HScrollBar"]:
        theme.set_stylebox("scroll", axis, _flat("ui_bg"))
        theme.set_stylebox("grabber", axis, _flat("ui_border"))
        theme.set_stylebox("grabber_highlight", axis, _flat("ui_border_light"))
        theme.set_stylebox("grabber_pressed", axis, _flat("accent_orange"))
    return theme

## 9-slice from a generated frame sprite. `border` is the slice inset; `margin`
## is how far content is kept clear of the frame.
static func _frame(name: String, border: int, margin: int) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    var path: String = FRAME_DIR % name
    if ResourceLoader.exists(path):
        style.texture = load(path)
    style.set_texture_margin_all(border)
    style.content_margin_left = float(border + margin)
    style.content_margin_right = float(border + margin)
    style.content_margin_top = float(border + margin - 1)
    style.content_margin_bottom = float(border + margin - 1)
    return style

static func _flat(colour: String) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PixelPalette.get_colour(colour)
    return style
