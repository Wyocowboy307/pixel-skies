class_name PixelTheme
extends RefCounted
## Builds the game Theme from the generated pixel frames.
##
## The direction is a bright pixel game, not an admin panel: white cards with a
## navy edge, saturated chunky buttons, a sky-blue HUD bar. Everything is a
## 9-slice of a generated sprite and every colour comes from the locked palette.

const FONT := "ui/font5x7.fnt"
const FRAME_DIR := "ui/%s.png"
const FONT_SIZE := 7

static func build() -> Theme:
    var theme := Theme.new()
    var font: Font = load(AssetPaths.resolve_file(FONT))
    theme.default_font = font
    theme.default_font_size = FONT_SIZE

    # Cards are the default surface.
    theme.set_stylebox("panel", "PanelContainer", _frame("card", 6, 4))
    theme.set_stylebox("panel", "Panel", _frame("card", 6, 4))
    theme.set_type_variation("CardRaised", "PanelContainer")
    theme.set_stylebox("panel", "CardRaised", _frame("card_raised", 6, 4))
    theme.set_type_variation("HudBar", "PanelContainer")
    theme.set_stylebox("panel", "HudBar", _frame("hud_bar", 6, 3))

    # Plain buttons: cream, chunky.
    for state: String in ["normal", "hover", "pressed", "disabled"]:
        theme.set_stylebox(state, "Button", _frame("btn_plain_%s" % state, 6, 3))
    theme.set_stylebox("focus", "Button", _frame("btn_plain_hover", 6, 3))
    theme.set_font("font", "Button", font)
    theme.set_font_size("font_size", "Button", FONT_SIZE)
    theme.set_color("font_color", "Button", PixelPalette.get_colour("navy"))
    theme.set_color("font_hover_color", "Button", PixelPalette.get_colour("navy_deep"))
    theme.set_color("font_pressed_color", "Button", PixelPalette.get_colour("card_hi"))
    theme.set_color("font_disabled_color", "Button", PixelPalette.get_colour("card_lo"))
    theme.set_constant("h_separation", "Button", 3)

    # The three big saturated actions: LOAD, ROUTE, FLY.
    for kind: String in ["green", "blue", "orange"]:
        var variation: String = "Btn" + kind.capitalize()
        theme.set_type_variation(variation, "Button")
        for state: String in ["normal", "hover", "pressed", "disabled"]:
            theme.set_stylebox(state, variation, _frame("btn_%s_%s" % [kind, state], 6, 4))
        theme.set_font("font", variation, font)
        theme.set_font_size("font_size", variation, FONT_SIZE * 2)
        theme.set_color("font_color", variation, PixelPalette.get_colour("white"))
        theme.set_color("font_hover_color", variation, PixelPalette.get_colour("white"))
        theme.set_color("font_pressed_color", variation, PixelPalette.get_colour("card_hi"))
        theme.set_color("font_disabled_color", variation, PixelPalette.get_colour("card_hi"))

    theme.set_font("font", "Label", font)
    theme.set_font_size("font_size", "Label", FONT_SIZE)
    theme.set_color("font_color", "Label", PixelPalette.get_colour("navy"))

    # Text entry (registration, nickname) on the customize screen.
    theme.set_stylebox("normal", "LineEdit", _frame("card_raised", 6, 3))
    theme.set_stylebox("focus", "LineEdit", _frame("btn_blue_hover", 6, 3))
    theme.set_font("font", "LineEdit", font)
    theme.set_font_size("font_size", "LineEdit", FONT_SIZE)
    theme.set_color("font_color", "LineEdit", PixelPalette.get_colour("navy"))
    theme.set_color("caret_color", "LineEdit", PixelPalette.get_colour("accent_orange"))

    for axis: String in ["VScrollBar", "HScrollBar"]:
        theme.set_stylebox("scroll", axis, _flat("card_lo"))
        theme.set_stylebox("grabber", axis, _flat("navy"))
        theme.set_stylebox("grabber_highlight", axis, _flat("hud_blue"))
        theme.set_stylebox("grabber_pressed", axis, _flat("accent_orange"))
    return theme

static func _frame(name: String, border: int, margin: int) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = AssetPaths.load_texture(FRAME_DIR % name)
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
