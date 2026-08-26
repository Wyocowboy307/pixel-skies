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

## A big, obviously-pressable action button (Load / Route / Fly).
static func action(text: String) -> Button:
    var node := Button.new()
    node.text = text
    node.theme_type_variation = "ActionButton"
    node.add_theme_font_size_override("font_size", FONT_SIZE)
    node.custom_minimum_size = Vector2(72.0, 22.0)
    return node

static func label(text: String, colour_key: String = "ink") -> Label:
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

## The aircraft's own map sprite, cropped to its first heading — a badge that
## says which plane rather than a generic icon.
static func aircraft_badge(family_id: String) -> TextureRect:
    var node := TextureRect.new()
    var strip: Texture2D = AircraftSprites.map_strip(family_id)
    if strip != null:
        var frame: float = strip.get_size().y
        var atlas := AtlasTexture.new()
        atlas.atlas = strip
        atlas.region = Rect2(0.0, 0.0, frame, frame)
        node.texture = atlas
        node.custom_minimum_size = Vector2(frame, frame)
    node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return node

## A single passenger or crate, used to show capacity as things rather than pips.
static func payload_pip(is_seat: bool, filled: bool, variant: int = 0) -> Control:
    if not filled:
        var empty := ColorRect.new()
        empty.custom_minimum_size = Vector2(7.0, 9.0) if is_seat else Vector2(9.0, 9.0)
        empty.color = colour("ui_bg")
        return empty
    var node := TextureRect.new()
    var path: String = "res://assets/art/people/traveller_teal.png" if is_seat \
        else "res://assets/art/cargo/crate_box.png"
    if is_seat:
        var shirts: Array[String] = ["teal", "orange", "green", "red", "grey"]
        path = "res://assets/art/people/traveller_%s.png" % shirts[variant % shirts.size()]
    if ResourceLoader.exists(path):
        node.texture = load(path)
    node.custom_minimum_size = Vector2(8.0, 12.0) if is_seat else Vector2(12.0, 12.0)
    node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return node

## Plain-language job description: "2 PEOPLE" rather than "2 PASSENGERS".
static func job_summary(job: Job) -> String:
    if job.kind == "passenger":
        return "%d PERSON" % job.seats if job.seats == 1 else "%d PEOPLE" % job.seats
    if job.cargo_units == 1:
        return "1 CRATE"
    return "%d CRATES" % job.cargo_units

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
