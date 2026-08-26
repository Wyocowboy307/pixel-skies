class_name Hud
extends Control
## Permanent minimal HUD plus the contextual selected-airport card.
##
## Built in code so the layout lives next to the logic that fills it. UI sits in
## a CanvasLayer and never scales with world zoom (docs/UI_UX.md).

signal focus_requested(airport_id: String)
signal home_requested()

const PANEL_BG := Color("#0d1c26", 0.94)
const PANEL_EDGE := Color("#2c4a5a")
const TEXT := Color("#e8f1f4")
const TEXT_DIM := Color("#8fa8b4")
const ACCENT := Color("#f3ad63")

var db: GameDB
var sim: Simulation

var _top_bar: PanelContainer
var _zoom_label: Label
var _money_label: Label
var _fleet_label: Label
var _card: PanelContainer
var _card_code: Label
var _card_city: Label
var _card_facts: Label
var _focus_button: Button
var _selected_airport_id := ""

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_top_bar()
    _build_airport_card()

func bind(database: GameDB) -> void:
    db = database

func bind_sim(simulation: Simulation) -> void:
    sim = simulation
    set_money(sim.state.money)

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_BG
    style.border_color = PANEL_EDGE
    style.set_border_width_all(1)
    style.set_corner_radius_all(3)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    return style

func _build_top_bar() -> void:
    _top_bar = PanelContainer.new()
    _top_bar.add_theme_stylebox_override("panel", _panel_style())
    _top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _top_bar.offset_left = 0.0
    _top_bar.offset_right = 0.0
    _top_bar.offset_top = 0.0
    _top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_top_bar)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 24)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _top_bar.add_child(row)

    var title := Label.new()
    title.text = "PIXEL SKIES"
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", TEXT)
    row.add_child(title)

    _money_label = Label.new()
    _money_label.add_theme_font_size_override("font_size", 18)
    _money_label.add_theme_color_override("font_color", ACCENT)
    row.add_child(_money_label)

    _fleet_label = Label.new()
    _fleet_label.add_theme_font_size_override("font_size", 13)
    _fleet_label.add_theme_color_override("font_color", TEXT_DIM)
    row.add_child(_fleet_label)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)

    _zoom_label = Label.new()
    _zoom_label.add_theme_font_size_override("font_size", 13)
    _zoom_label.add_theme_color_override("font_color", TEXT_DIM)
    row.add_child(_zoom_label)

    var hint := Label.new()
    hint.text = "wheel zoom · drag pan · click airport"
    hint.add_theme_font_size_override("font_size", 13)
    hint.add_theme_color_override("font_color", TEXT_DIM)
    row.add_child(hint)

func _build_airport_card() -> void:
    _card = PanelContainer.new()
    _card.add_theme_stylebox_override("panel", _panel_style())
    _card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _card.offset_left = 18.0
    _card.offset_top = -150.0
    _card.offset_bottom = -18.0
    _card.custom_minimum_size = Vector2(260.0, 0.0)
    _card.visible = false
    add_child(_card)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    _card.add_child(column)

    _card_code = Label.new()
    _card_code.add_theme_font_size_override("font_size", 24)
    _card_code.add_theme_color_override("font_color", ACCENT)
    column.add_child(_card_code)

    _card_city = Label.new()
    _card_city.add_theme_font_size_override("font_size", 14)
    _card_city.add_theme_color_override("font_color", TEXT)
    column.add_child(_card_city)

    _card_facts = Label.new()
    _card_facts.add_theme_font_size_override("font_size", 12)
    _card_facts.add_theme_color_override("font_color", TEXT_DIM)
    column.add_child(_card_facts)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 6)
    column.add_child(buttons)

    _focus_button = Button.new()
    _focus_button.text = "Zoom In"
    _focus_button.pressed.connect(_on_focus_pressed)
    buttons.add_child(_focus_button)

    var home := Button.new()
    home.text = "World"
    home.pressed.connect(func() -> void: home_requested.emit())
    buttons.add_child(home)

# ---------------------------------------------------------------------------
# Updates
# ---------------------------------------------------------------------------

func set_money(amount: int) -> void:
    _money_label.text = "$%s" % Simulation._money(amount)
    if sim != null:
        var fleet: Dictionary = sim.state.fleet_summary()
        _fleet_label.text = "fleet %d · %d flying" % [int(fleet["total"]), int(fleet["flying"])]

func set_zoom_readout(zoom: float, tier_name: String) -> void:
    _zoom_label.text = "zoom %.2fx · %s" % [zoom, tier_name]

func show_airport(airport_id: String) -> void:
    if db == null or not db.airports.has(airport_id):
        return
    _selected_airport_id = airport_id
    var airport: Dictionary = db.airports[airport_id]
    _card_code.text = String(airport["code"])
    _card_city.text = "%s, %s" % [String(airport["city"]), String(airport["region"])]
    _card_facts.text = "%s field · runway band %d" % [
        String(airport["tier"]).capitalize(), int(airport["runway_band"])]
    _card.visible = true

func clear_airport() -> void:
    _selected_airport_id = ""
    _card.visible = false

func _on_focus_pressed() -> void:
    if not _selected_airport_id.is_empty():
        focus_requested.emit(_selected_airport_id)
