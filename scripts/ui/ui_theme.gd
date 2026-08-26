class_name UiTheme
extends RefCounted
## Shared colours and widget builders for the HUD.
##
## Panels are dark and compact so they never bury the airplane
## (docs/UI_UX.md, "Prime directive").

const BG := Color("#0d1c26", 0.95)
const BG_SOLID := Color("#0d1c26")
const ROW := Color("#142836", 0.9)
const ROW_HOVER := Color("#1d3948")
const EDGE := Color("#2c4a5a")
const TEXT := Color("#e8f1f4")
const TEXT_DIM := Color("#8fa8b4")
const ACCENT := Color("#f3ad63")
const GOOD := Color("#7fc99a")
const BAD := Color("#d98a7a")
const PASSENGER := Color("#8fc7d6")
const CARGO := Color("#d3ac57")
const CONTRACT := Color("#c79ae0")
const SLOT_EMPTY := Color("#24404f")
const SLOT_FILLED := Color("#8fc7d6")

static func panel(alpha_bg: Color = BG) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = alpha_bg
    style.border_color = EDGE
    style.set_border_width_all(1)
    style.set_corner_radius_all(3)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    return style

static func row_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(2)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style

static func label(text: String, size: int, color: Color) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_size_override("font_size", size)
    node.add_theme_color_override("font_color", color)
    return node

static func button(text: String) -> Button:
    var node := Button.new()
    node.text = text
    node.add_theme_font_size_override("font_size", 13)
    return node

static func kind_color(kind: String) -> Color:
    match kind:
        "passenger": return PASSENGER
        "cargo": return CARGO
        "contract": return CONTRACT
        _: return TEXT_DIM

static func kind_glyph(kind: String) -> String:
    match kind:
        "passenger": return "PAX"
        "cargo": return "CGO"
        "contract": return "JOB"
        _: return "?"

## "1h 04m" / "12m" — short enough for a table cell.
static func duration(seconds: float) -> String:
    var total: int = maxi(0, roundi(seconds))
    var hours: int = total / 3600
    var minutes: int = (total % 3600) / 60
    if hours > 0:
        return "%dh %02dm" % [hours, minutes]
    if minutes > 0:
        return "%dm" % minutes
    return "%ds" % (total % 60)

static func money(amount: int) -> String:
    return "$%s" % Simulation._money(amount)
