class_name UiTheme
extends RefCounted
## Layout constants and widget builders for a 640x360 screen.
##
## Sizes are small on purpose: at this resolution a row is 11 px and the font is
## 7 px, so panels have to be terse. Colours all come from the locked palette.

const SCREEN := Vector2(640.0, 360.0)
const TOP_BAR_HEIGHT := 15.0
const PANEL_WIDTH := 150.0
const DOCK_WIDTH := 296.0
const DOCK_HEIGHT := 84.0
const ROW_HEIGHT := 20.0
const FONT_SIZE := 7
const MARGIN := 4.0

static func colour(key: String) -> Color:
    return PixelPalette.get_colour(key)

static func label(text: String, colour_key: String = "text") -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_size_override("font_size", FONT_SIZE)
    node.add_theme_color_override("font_color", colour(colour_key))
    return node

static func button(text: String) -> Button:
    var node := Button.new()
    node.text = text
    node.add_theme_font_size_override("font_size", FONT_SIZE)
    node.custom_minimum_size = Vector2(0.0, 13.0)
    return node

static func icon(name: String) -> TextureRect:
    var node := TextureRect.new()
    var path: String = "res://assets/art/ui/icons/%s.png" % name
    if ResourceLoader.exists(path):
        node.texture = load(path)
    node.custom_minimum_size = Vector2(10.0, 10.0)
    node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return node

static func kind_icon(kind: String) -> String:
    match kind:
        "passenger": return "passenger"
        "cargo": return "cargo"
        "contract": return "contract"
        _: return "cargo"

static func kind_colour(kind: String) -> Color:
    match kind:
        "passenger": return colour("accent_teal")
        "cargo": return colour("accent_yellow")
        "contract": return colour("accent_orange_light")
        _: return colour("text_dim")

## "1h04" / "12m" — short enough for a 150 px panel.
static func duration(seconds: float) -> String:
    var total: int = maxi(0, roundi(seconds))
    var hours: int = total / 3600
    var minutes: int = (total % 3600) / 60
    if hours > 0:
        return "%dh%02d" % [hours, minutes]
    if minutes > 0:
        return "%dm" % minutes
    return "%ds" % (total % 60)

static func money(amount: int) -> String:
    return "$%s" % Simulation._money(amount)
