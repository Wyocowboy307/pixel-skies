class_name Hud
extends Control
## Permanent top bar plus the contextual selected-airport card.
##
## At 640x360 the HUD has to be terse: a 22 px plate and a card barely wider
## than its text. The airfield stays visible between them (docs/UI_UX.md).

signal focus_requested(airport_id: String)
signal home_requested()

var db: GameDB
var sim: Simulation

var _money_label: Label
var _fleet_label: Label
var _zoom_label: Label
var _follow_chip: PanelContainer
var _follow_label: Label
var _card: PanelContainer
var _card_code: Label
var _card_city: Label
var _card_facts: Label
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

func _build_top_bar() -> void:
    var bar := PanelContainer.new()
    bar.theme_type_variation = "HudTop"
    bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    # The chunky frame is part of the look now: only the black outline row
    # hangs off the top of the screen, so the lit lip shows along the top and
    # the shaded navy base edge along the bottom. Sides bleed off so the plate
    # runs edge to edge. Height comes from these offsets, not TOP_BAR_HEIGHT:
    # a 22px visible plate fits the inset money/fleet plates exactly.
    bar.offset_bottom = UiTheme.TOP_BAR_HEIGHT + 7.0
    bar.offset_left = -2.0
    bar.offset_right = 2.0
    bar.offset_top = -1.0
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bar)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.add_child(row)

    _money_label = UiTheme.label("", "white")
    row.add_child(_plate("money", _money_label))

    _fleet_label = UiTheme.label("", "card_hi")
    row.add_child(_plate("plane", _fleet_label))

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)

    _zoom_label = UiTheme.label("", "card_hi")
    row.add_child(_zoom_label)

## Money and fleet each sit on a small inset plate with their icon, so the
## readouts look like gauges built into the bar rather than floating text.
func _plate(icon_name: String, value: Label) -> PanelContainer:
    var plate := PanelContainer.new()
    plate.theme_type_variation = "HudPlate"
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box := HBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    plate.add_child(box)
    var icon := UiTheme.icon(icon_name)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(icon)
    value.mouse_filter = Control.MOUSE_FILTER_IGNORE
    value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    box.add_child(value)
    return plate

## A luggage-tag chip that says the camera is locked to an aircraft, and how
## to stop — the same warm tag language as the map's callsign chip.
func set_following(text: String) -> void:
    if _follow_chip == null:
        _follow_chip = PanelContainer.new()
        _follow_chip.theme_type_variation = "TagChip"
        _follow_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
        _follow_chip.offset_top = 26.0
        _follow_chip.offset_left = -80.0
        _follow_chip.offset_right = 80.0
        _follow_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_follow_chip)
        _follow_label = UiTheme.label("", "navy")
        _follow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _follow_chip.add_child(_follow_label)
    _follow_chip.visible = not text.is_empty()
    _follow_label.text = text

func _build_airport_card() -> void:
    _card = PanelContainer.new()
    _card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _card.offset_left = UiTheme.MARGIN
    _card.offset_top = -56.0
    _card.offset_bottom = -UiTheme.MARGIN
    _card.custom_minimum_size = Vector2(112.0, 0.0)
    _card.visible = false
    add_child(_card)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 1)
    _card.add_child(column)

    _card_code = UiTheme.heading("", "accent_orange")
    column.add_child(_card_code)
    _card_city = UiTheme.label("", "text")
    column.add_child(_card_city)
    _card_facts = UiTheme.label("", "text_dim")
    column.add_child(_card_facts)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 3)
    column.add_child(buttons)
    var open := UiTheme.button("OPEN")
    open.pressed.connect(func() -> void:
        if not _selected_airport_id.is_empty():
            focus_requested.emit(_selected_airport_id))
    buttons.add_child(open)
    var home := UiTheme.button("WORLD")
    home.pressed.connect(func() -> void: home_requested.emit())
    buttons.add_child(home)

func set_money(amount: int) -> void:
    _money_label.text = UiTheme.money(amount)
    if sim != null:
        var fleet: Dictionary = sim.state.fleet_summary()
        _fleet_label.text = "%d/%d" % [int(fleet["flying"]), int(fleet["total"])]

func set_zoom_readout(_zoom: float, _tier_name: String) -> void:
    # Engine telemetry never ships in the player HUD — every review lens called
    # the LOD readout the loudest "technical application" tell in the build.
    _zoom_label.text = ""

func show_airport(airport_id: String) -> void:
    if db == null or not db.airports.has(airport_id):
        return
    _selected_airport_id = airport_id
    var airport: Dictionary = db.airports[airport_id]
    _card_code.text = String(airport["code"])
    _card_city.text = String(airport["city"])
    var waiting: int = 0
    if sim != null:
        waiting = sim.state.jobs_at(airport_id).size()
    _card_facts.text = "%s · rwy %d · %d jobs" % [
        String(airport["tier"]).substr(0, 3), int(airport["runway_band"]), waiting]
    _card.visible = true

func clear_airport() -> void:
    _selected_airport_id = ""
    _card.visible = false
